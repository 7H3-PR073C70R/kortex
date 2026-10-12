import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating Interactive Bottom Action Dock for Voice Dialogue Modal.
class VoiceDialogueActionDock extends StatelessWidget {
  const VoiceDialogueActionDock({
    required this.stateColor,
    required this.isDesktop,
    required this.state,
    required this.isMuted,
    required this.liveTranscript,
    required this.onToggleMute,
    required this.onInteractionTap,
    required this.onCloseModal,
    super.key,
  });

  final Color stateColor;
  final bool isDesktop;
  final DialogueState state;
  final bool isMuted;
  final String liveTranscript;
  final VoidCallback onToggleMute;
  final VoidCallback onInteractionTap;
  final VoidCallback onCloseModal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isListening = state == DialogueState.listening;
    final isSpeaking = state == DialogueState.speaking;
    final hasSpeech = liveTranscript.trim().isNotEmpty;

    final buttonLabel = isListening
        ? (hasSpeech
              ? l10n.voiceDialogueDoneSpeaking
              : l10n.voiceDialogueListening)
        : isSpeaking
        ? l10n.voiceDialogueTapToSpeak
        : l10n.voiceDialogueTapToSpeak;

    final buttonIcon = isListening
        ? (hasSpeech ? Icons.arrow_upward_rounded : Icons.mic_rounded)
        : Icons.mic_rounded;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 480 : double.infinity,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary.withValues(
              alpha: isDark ? 0.9 : 0.8,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: colors.surfaceBorder.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 1. Mute Output Toggle Button
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onToggleMute,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isMuted
                          ? colors.error.withValues(alpha: 0.15)
                          : colors.surfacePrimary,
                      border: Border.all(
                        color: isMuted
                            ? colors.error.withValues(alpha: 0.4)
                            : colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: isMuted ? colors.error : colors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 2. Primary Hero Interaction Button
              Expanded(
                child: ShrinkableButton(
                  onTap: onInteractionTap,
                  child: Material(
                    color: stateColor,
                    borderRadius: BorderRadius.circular(24),
                    elevation: 2,
                    shadowColor: stateColor.withValues(alpha: 0.35),
                    child: InkWell(
                      onTap: onInteractionTap,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              buttonIcon,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                buttonLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // 3. End Session Button
              Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onCloseModal,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surfacePrimary,
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
