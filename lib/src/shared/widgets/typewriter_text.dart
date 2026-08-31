import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Animated typewriter text widget that simulates natural
/// character-by-character typing for conversational AI messages.
class TypewriterText extends HookWidget {
  const TypewriterText({
    required this.text,
    required this.style,
    super.key,
    this.isStreaming = true,
    this.onComplete,
    this.onTick,
    this.charDuration = const Duration(milliseconds: 14),
  });

  final String text;
  final TextStyle style;
  final bool isStreaming;
  final VoidCallback? onComplete;
  final VoidCallback? onTick;
  final Duration charDuration;

  @override
  Widget build(BuildContext context) {
    final displayedCount = useState<int>(isStreaming ? 0 : text.length);

    useEffect(() {
      if (!isStreaming) {
        displayedCount.value = text.length;
        return null;
      }

      displayedCount.value = 0;
      Timer? timer;
      timer = Timer.periodic(charDuration, (t) {
        if (displayedCount.value < text.length) {
          displayedCount.value += 1;
          onTick?.call();
        } else {
          t.cancel();
          onComplete?.call();
        }
      });

      return () => timer?.cancel();
    }, [text, isStreaming]);

    final visibleSubstring = isStreaming
        ? text.substring(0, displayedCount.value.clamp(0, text.length))
        : text;

    return Text(
      visibleSubstring,
      style: style,
    );
  }
}
