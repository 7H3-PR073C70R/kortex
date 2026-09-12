import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

/// An accessible button that reads flashcard text aloud using Text-To-Speech (FSR-12).
class AudioPronounceButton extends HookWidget {
  const AudioPronounceButton({
    required this.textToPronounce, super.key,
    this.ttsHandler,
    this.size = 36.0,
    this.iconSize = 18.0,
    this.tooltip = 'Pronounce card content',
  });

  final String textToPronounce;
  final TextToSpeechHandler? ttsHandler;
  final double size;
  final double iconSize;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final handler = useMemoized(() => ttsHandler ?? TextToSpeechHandler());
    final isSpeaking = useValueListenable(handler.isSpeakingNotifier);

    useEffect(() {
      return () {
        if (ttsHandler == null) {
          handler.dispose();
        }
      };
    }, const []);

    return Semantics(
      label: isSpeaking ? 'Stop audio pronunciation' : tooltip,
      button: true,
      child: Material(
        color: isSpeaking ? colors.primary.withValues(alpha: 0.2) : colors.surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(size / 2),
          side: BorderSide(
            color: isSpeaking ? colors.primary : colors.surfaceBorder.withValues(alpha: 0.5),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: () async {
            AppFeedback.selection();
            if (isSpeaking) {
              await handler.stop();
            } else {
              if (textToPronounce.trim().isNotEmpty) {
                await handler.speak(textToPronounce);
              }
            }
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                size: iconSize,
                color: isSpeaking ? colors.primary : colors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
