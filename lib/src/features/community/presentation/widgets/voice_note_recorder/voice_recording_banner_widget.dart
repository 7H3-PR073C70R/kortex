import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/widgets/voice_note_recorder/audio_waveform_visualizer.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Real-life grade Voice Recording Banner displayed when recording is active.
/// Shows only the REC indicator, live timer, and waveform — the mic button
/// in the parent toolbar acts as the single stop control.
class VoiceRecordingBannerWidget extends HookWidget {
  const VoiceRecordingBannerWidget({
    required this.durationSeconds,
    this.isLocked = false,
    this.transcriptText = '',
    this.amplitudeStream,
    // Legacy cancel/done params kept for callers that still pass them;
    // they are no longer rendered inside the banner itself.
    this.onCancel,
    this.onDone,
    super.key,
  });

  final bool isLocked;
  final int durationSeconds;
  final VoidCallback? onCancel;
  final VoidCallback? onDone;
  final String transcriptText;
  final Stream<double>? amplitudeStream;

  static String formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isTranscriptExpanded = useState<bool>(false);

    return AnimatedContainer(
      duration: AppMotion.snappy,
      curve: AppMotion.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.error.withAlpha(isDark ? 30 : 16),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.error.withAlpha(isDark ? 80 : 45),
          width: 1.2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Red pulsing rec dot
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.error,
                  boxShadow: [
                    BoxShadow(
                      color: colors.error.withAlpha(140),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Recording Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.error.withAlpha(isDark ? 55 : 30),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  'REC',
                  style: typography.caption.bold.copyWith(
                    color: colors.error,
                    fontSize: 10,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Live Duration
              Text(
                formatDuration(durationSeconds),
                style: typography.body.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),

              // Animated Waveform Visualizer — takes remaining space
              Expanded(
                child: AudioWaveformVisualizer(
                  amplitudeStream: amplitudeStream,
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    onCancel?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.error.withAlpha(isDark ? 50 : 25),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: colors.error,
                    ),
                  ),
                ),
              ],
              if (onDone != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    unawaited(HapticFeedback.mediumImpact());
                    onDone?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withAlpha(isDark ? 70 : 40),
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (transcriptText.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                isTranscriptExpanded.value = !isTranscriptExpanded.value;
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.subtitles_rounded,
                    size: 12,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isTranscriptExpanded.value
                        ? 'Hide Live STT Preview 📝'
                        : 'Show Live STT Preview 📝',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    isTranscriptExpanded.value
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 14,
                    color: colors.textSecondary,
                  ),
                ],
              ),
            ),
            if (isTranscriptExpanded.value) ...[
              const SizedBox(height: 4),
              Text(
                transcriptText.trim(),
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
