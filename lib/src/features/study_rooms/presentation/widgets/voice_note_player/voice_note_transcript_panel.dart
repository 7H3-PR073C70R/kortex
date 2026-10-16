import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Expanded panel rendering voice note transcription states:
/// live AI transcribing progress, transcription errors with retry,
/// or full transcript with copy and scrolling affordances.
class VoiceNoteTranscriptPanel extends StatelessWidget {
  const VoiceNoteTranscriptPanel({
    required this.isTranscribing,
    required this.transcriptionError,
    required this.currentTranscript,
    required this.effectiveTranscript,
    required this.onRetry,
    required this.onCopyTranscript,
    super.key,
  });

  final bool isTranscribing;
  final String? transcriptionError;
  final String? currentTranscript;
  final String? effectiveTranscript;
  final VoidCallback onRetry;
  final void Function(BuildContext context, String text) onCopyTranscript;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(200)
            : colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effectiveTranscript != null
              ? colors.primary.withAlpha(isDark ? 55 : 35)
              : transcriptionError != null
                  ? colors.error.withAlpha(isDark ? 80 : 50)
                  : colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
        ),
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    if (isTranscribing) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Transcribing voice note with AI Whisper...',
              style: typography.caption.medium.copyWith(
                color: colors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      );
    }

    if (transcriptionError != null) {
      return ShrinkableButton(
        onTap: onRetry,
        child: Row(
          children: [
            Icon(
              Icons.refresh_rounded,
              size: 16,
              color: colors.error,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                transcriptionError!,
                style: typography.caption.medium.copyWith(
                  color: colors.error,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colors.error.withAlpha(isDark ? 40 : 20),
                borderRadius: AppRadius.radiusMicro,
              ),
              child: Text(
                'Retry',
                style: typography.caption.bold.copyWith(
                  color: colors.error,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (currentTranscript != null && currentTranscript!.trim().isNotEmpty) {
      final text = currentTranscript!.trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 14,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SPEECH-TO-TEXT TRANSCRIPT',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              ShrinkableButton(
                onTap: () => onCopyTranscript(context, text),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 20),
                    borderRadius: AppRadius.radiusMicro,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 11,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: typography.body.regular.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ShrinkableButton(
      onTap: onRetry,
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No transcript available. Tap to transcribe with AI 🎙️',
              style: typography.caption.medium.copyWith(
                color: colors.primary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
