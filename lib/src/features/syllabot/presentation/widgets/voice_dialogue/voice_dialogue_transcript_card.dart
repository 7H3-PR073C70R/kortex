import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// User Live Transcription Card for Voice Dialogue Modal.
class VoiceDialogueTranscriptCard extends StatelessWidget {
  const VoiceDialogueTranscriptCard({
    required this.liveTranscript,
    required this.isTranscriptExpanded,
    required this.state,
    required this.onToggleExpanded,
    super.key,
  });

  final String liveTranscript;
  final bool isTranscriptExpanded;
  final DialogueState state;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShrinkableButton(
          onTap: onToggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: colors.primary.withValues(alpha: isDark ? 0.3 : 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.subtitles_rounded,
                  size: 13,
                  color: colors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  isTranscriptExpanded
                      ? 'Hide Speech-to-Text 📝'
                      : 'Show Speech-to-Text (STT) 📝',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isTranscriptExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 14,
                  color: colors.primary,
                ),
              ],
            ),
          ),
        ),
        if (isTranscriptExpanded) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 580),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: state == DialogueState.listening
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.surfaceBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              '"$liveTranscript"',
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: typography.body.medium.copyWith(
                color: colors.textPrimary,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
