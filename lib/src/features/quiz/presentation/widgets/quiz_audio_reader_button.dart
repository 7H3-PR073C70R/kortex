import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

/// Audio speaker button that synthesizes quiz questions and MCQ options (QZ-15).
class QuizAudioReaderButton extends HookWidget {
  const QuizAudioReaderButton({
    required this.questionText, required this.options, super.key,
    this.ttsHandler,
    this.size = 36.0,
    this.iconSize = 18.0,
  });

  final String questionText;
  final List<String> options;
  final TextToSpeechHandler? ttsHandler;
  final double size;
  final double iconSize;

  String _buildSpeechScript() {
    final buffer = StringBuffer('Question: $questionText. ');
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    for (var i = 0; i < options.length; i++) {
      final label = i < labels.length ? labels[i] : '${i + 1}';
      buffer.write('Option $label: ${options[i]}. ');
    }
    return buffer.toString();
  }

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
      label: isSpeaking ? 'Stop reading question' : 'Read question and options aloud',
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
              final script = _buildSpeechScript();
              await handler.speak(script);
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
