import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Morphing trailing action widget in the Syllabot chat input bar.
///
/// Switches smoothly between:
/// - Primary Send button when user input is present (or speech not supported).
/// - Pulsing Mic / Interruption button when listening or AI is speaking.
class SyllabotVoiceSendAction extends StatelessWidget {
  const SyllabotVoiceSendAction({
    required this.hasInput,
    required this.isListening,
    required this.isAiSpeaking,
    required this.isLoading,
    required this.micPulseController,
    required this.onSend,
    required this.onMicTap,
    required this.onMicLongPress,
    this.hasVoiceDialogue = false,
    super.key,
  });

  final bool hasInput;
  final bool isListening;
  final bool isAiSpeaking;
  final bool isLoading;
  final AnimationController micPulseController;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final VoidCallback onMicLongPress;
  final bool hasVoiceDialogue;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final showSendButton = (hasInput && !isListening) ||
        (!SpeechToTextHandler.isPlatformSupported && !isAiSpeaking);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: child,
      ),
      child: showSendButton
          ? PlatformHoverBuilder(
              key: const ValueKey('send_action'),
              builder: (context, isHovered, child) {
                return ShrinkableButton(
                  onTap: onSend,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isHovered ? 50 : 25),
                          blurRadius: isHovered ? 12 : 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isLoading
                        ? Center(
                            child: AppLogoLoader(
                              size: 18,
                              color: colors.white,
                              showMessage: false,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            color: colors.white,
                            size: 20,
                          ),
                  ),
                );
              },
            )
          : AnimatedBuilder(
              key: const ValueKey('voice_action_builder'),
              animation: micPulseController,
              builder: (context, _) {
                final pulse = micPulseController.value;
                return Tooltip(
                  message: isAiSpeaking
                      ? 'Syllabot is speaking • Tap to interrupt'
                      : (isListening
                          ? 'Listening... Tap to stop'
                          : (hasVoiceDialogue
                              ? 'Voice Dialogue • Tap to start conversation'
                              : 'Voice Input • Tap to dictate')),
                  child: PlatformHoverBuilder(
                    key: ValueKey(
                      isAiSpeaking
                          ? 'ai_speaking_action'
                          : (isListening
                              ? 'mic_listening_action'
                              : 'voice_action'),
                    ),
                    builder: (context, isHovered, child) {
                      return ShrinkableButton(
                        onTap: onMicTap,
                        onLongPress: onMicLongPress,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (isListening || isAiSpeaking)
                              Container(
                                width: 36 + (pulse * 12),
                                height: 36 + (pulse * 12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isAiSpeaking
                                      ? colors.syllabotAccent.withAlpha(
                                          (70 * (1 - pulse)).toInt(),
                                        )
                                      : colors.error.withAlpha(
                                          (90 * (1 - pulse)).toInt(),
                                        ),
                                ),
                              ),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isAiSpeaking
                                    ? colors.syllabotAccent.withAlpha(45)
                                    : (isListening
                                        ? colors.error
                                        : (isHovered
                                            ? colors.primary.withAlpha(20)
                                            : colors.surfaceSecondary)),
                                shape: BoxShape.circle,
                                boxShadow: (isAiSpeaking || isListening)
                                    ? [
                                        BoxShadow(
                                          color: colors.black.withAlpha(
                                            isDark ? 50 : 20,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                                border: Border.all(
                                  color: isAiSpeaking
                                      ? colors.syllabotAccent
                                      : (isListening
                                          ? colors.white.withAlpha(180)
                                          : (isHovered
                                              ? colors.primary.withAlpha(120)
                                              : colors.surfaceBorder.withAlpha(
                                                  80,
                                                ))),
                                  width: isAiSpeaking ? 1.5 : 1,
                                ),
                              ),
                              child: Icon(
                                isAiSpeaking
                                    ? Icons.graphic_eq_rounded
                                    : (isListening
                                        ? Icons.stop_rounded
                                        : (isHovered
                                            ? Icons.mic_rounded
                                            : Icons.mic_none_rounded)),
                                color: isAiSpeaking
                                    ? colors.syllabotAccent
                                    : (isListening
                                        ? colors.white
                                        : (isHovered
                                            ? colors.primary
                                            : colors.textSecondary)),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
