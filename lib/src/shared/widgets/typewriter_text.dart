import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class _MarkdownSegment {
  const _MarkdownSegment({
    required this.text,
    this.isBold = false,
    this.isItalic = false,
  });

  final String text;
  final bool isBold;
  final bool isItalic;
}

List<_MarkdownSegment> _parseMarkdownSegments(String input) {
  final segments = <_MarkdownSegment>[];
  final regex = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*)');
  var lastEnd = 0;

  for (final match in regex.allMatches(input)) {
    if (match.start > lastEnd) {
      segments.add(
        _MarkdownSegment(text: input.substring(lastEnd, match.start)),
      );
    }

    final fullMatch = match.group(0)!;
    if (fullMatch.startsWith('**') && fullMatch.endsWith('**')) {
      final content = match.group(2) ?? '';
      segments.add(_MarkdownSegment(text: content, isBold: true));
    } else if (fullMatch.startsWith('*') && fullMatch.endsWith('*')) {
      final content = match.group(3) ?? '';
      segments.add(_MarkdownSegment(text: content, isItalic: true));
    }

    lastEnd = match.end;
  }

  if (lastEnd < input.length) {
    segments.add(_MarkdownSegment(text: input.substring(lastEnd)));
  }

  return segments;
}

/// Animated typewriter text widget that simulates fast, natural
/// character-by-character streaming for conversational AI messages
/// while cleanly parsing and rendering markdown formatting (such as **bold**).
class TypewriterText extends HookWidget {
  const TypewriterText({
    required this.text,
    required this.style,
    super.key,
    this.isStreaming = true,
    this.onComplete,
    this.onTick,
    this.charDuration = const Duration(milliseconds: 6),
  });

  final String text;
  final TextStyle style;
  final bool isStreaming;
  final VoidCallback? onComplete;
  final VoidCallback? onTick;
  final Duration charDuration;

  @override
  Widget build(BuildContext context) {
    final segments = useMemoized(() => _parseMarkdownSegments(text), [text]);
    final cleanTotalCount = useMemoized(
      () => segments.fold<int>(
        0,
        (sum, seg) => sum + seg.text.characters.length,
      ),
      [segments],
    );

    final displayedCount = useState<int>(
      isStreaming ? 0 : cleanTotalCount,
    );

    useEffect(() {
      if (!isStreaming) {
        displayedCount.value = cleanTotalCount;
        return null;
      }

      displayedCount.value = 0;
      Timer? timer;
      timer = Timer.periodic(charDuration, (t) {
        if (displayedCount.value < cleanTotalCount) {
          final step = cleanTotalCount > 120 ? 2 : 1;
          final nextCount = displayedCount.value + step;
          displayedCount.value = nextCount.clamp(0, cleanTotalCount);
          onTick?.call();
        } else {
          t.cancel();
          onComplete?.call();
        }
      });

      return () => timer?.cancel();
    }, [text, isStreaming, cleanTotalCount]);

    var remainingToDisplay = isStreaming
        ? displayedCount.value
        : cleanTotalCount;

    final spans = <InlineSpan>[];
    for (final seg in segments) {
      if (remainingToDisplay <= 0) break;

      final segChars = seg.text.characters;
      final segLength = segChars.length;

      if (remainingToDisplay >= segLength) {
        spans.add(
          TextSpan(
            text: seg.text,
            style: style.copyWith(
              fontWeight: seg.isBold ? FontWeight.w700 : style.fontWeight,
              fontStyle: seg.isItalic ? FontStyle.italic : style.fontStyle,
            ),
          ),
        );
        remainingToDisplay -= segLength;
      } else {
        final partialText = segChars.take(remainingToDisplay).toString();
        spans.add(
          TextSpan(
            text: partialText,
            style: style.copyWith(
              fontWeight: seg.isBold ? FontWeight.w700 : style.fontWeight,
              fontStyle: seg.isItalic ? FontStyle.italic : style.fontStyle,
            ),
          ),
        );
        remainingToDisplay = 0;
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: style,
    );
  }
}
