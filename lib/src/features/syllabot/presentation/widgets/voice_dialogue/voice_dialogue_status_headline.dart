import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Status Headline displaying the current voice interaction status.
class VoiceDialogueStatusHeadline extends StatelessWidget {
  const VoiceDialogueStatusHeadline({
    required this.state,
    required this.liveTranscript,
    this.isCompact = false,
    super.key,
  });

  final DialogueState state;
  final String liveTranscript;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isListening = state == DialogueState.listening;
    final isThinking = state == DialogueState.thinking;
    final isSpeaking = state == DialogueState.speaking;
    final hasSpeech = liveTranscript.trim().isNotEmpty;

    final headline = isListening
        ? (hasSpeech
              ? l10n.voiceDialogueListening
              : l10n.voiceDialogueListening)
        : isThinking
        ? '${l10n.voiceDialogueThinking} & analyzing...'
        : isSpeaking
        ? l10n.voiceDialogueSpeaking
        : l10n.voiceDialogueTapToSpeak;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isListening) ...[
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: colors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
        Text(
          headline,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (isCompact ? typography.title3.bold : typography.title2.bold)
              .copyWith(
                color: colors.textPrimary,
                fontSize: isCompact ? 16 : 18,
              ),
        ),
      ],
    );
  }
}
