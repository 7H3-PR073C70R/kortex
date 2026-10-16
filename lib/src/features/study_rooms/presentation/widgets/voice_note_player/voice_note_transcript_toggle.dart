import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Expandable pill toggle button to reveal or conceal voice note transcripts.
class VoiceNoteTranscriptToggle extends StatelessWidget {
  const VoiceNoteTranscriptToggle({
    required this.isTranscribing,
    required this.isTranscriptExpanded,
    required this.effectiveTranscript,
    required this.onToggleTranscript,
    super.key,
  });

  final bool isTranscribing;
  final bool isTranscriptExpanded;
  final String? effectiveTranscript;
  final VoidCallback onToggleTranscript;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isActive = effectiveTranscript != null || isTranscribing;

    return Align(
      alignment: Alignment.centerLeft,
      child: ShrinkableButton(
        onTap: onToggleTranscript,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withAlpha(isDark ? 35 : 20)
                : colors.surfaceSecondary.withAlpha(isDark ? 120 : 80),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: isActive
                  ? colors.primary.withAlpha(isDark ? 70 : 40)
                  : colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
              width: 0.9,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isTranscribing) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 5),
              ] else ...[
                Icon(
                  Icons.subtitles_rounded,
                  size: 13,
                  color: effectiveTranscript != null
                      ? colors.primary
                      : colors.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                isTranscribing
                    ? 'Transcribing with AI... 🎙️'
                    : isTranscriptExpanded
                        ? 'Hide Transcript'
                        : 'Show Speech-to-Text 📝',
                style: typography.caption.bold.copyWith(
                  color: isActive ? colors.primary : colors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isTranscriptExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 15,
                color: isActive ? colors.primary : colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
