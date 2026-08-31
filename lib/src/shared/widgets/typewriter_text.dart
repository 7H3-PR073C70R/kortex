import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Animated typewriter text widget that simulates fast, natural
/// character-by-character streaming for conversational AI messages.
///
/// Uses [Characters] to safely handle multi-byte Unicode code points,
/// surrogate pairs, and emojis without producing malformed UTF-16 substrings.
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
    final characters = text.characters;
    final totalCount = characters.length;
    final displayedCount = useState<int>(isStreaming ? 0 : totalCount);

    useEffect(() {
      if (!isStreaming) {
        displayedCount.value = totalCount;
        return null;
      }

      displayedCount.value = 0;
      Timer? timer;
      timer = Timer.periodic(charDuration, (t) {
        if (displayedCount.value < totalCount) {
          // Dynamic step: 1 char for short text, 2 chars for long text
          final step = totalCount > 120 ? 2 : 1;
          final nextCount = displayedCount.value + step;
          displayedCount.value = nextCount.clamp(0, totalCount);
          onTick?.call();
        } else {
          t.cancel();
          onComplete?.call();
        }
      });

      return () => timer?.cancel();
    }, [text, isStreaming]);

    final visibleText = isStreaming
        ? characters.take(displayedCount.value).toString()
        : text;

    return Text(
      visibleText,
      style: style,
    );
  }
}
