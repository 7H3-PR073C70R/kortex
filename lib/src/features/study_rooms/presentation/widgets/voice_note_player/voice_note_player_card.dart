import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Primary playback card for `VoiceNotePlayerWidget` displaying play/pause controls,
/// progress bar, duration timestamps, playback speed pill, and optional delete button.
class VoiceNotePlayerCard extends StatelessWidget {
  const VoiceNotePlayerCard({
    required this.isPlaying,
    required this.position,
    required this.totalDuration,
    required this.playbackRate,
    required this.onTogglePlay,
    required this.onCyclePlaybackRate,
    this.onDelete,
    this.compact = false,
    super.key,
  });

  final bool isPlaying;
  final Duration position;
  final Duration totalDuration;
  final double playbackRate;
  final VoidCallback onTogglePlay;
  final VoidCallback onCyclePlaybackRate;
  final VoidCallback? onDelete;
  final bool compact;

  static String formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final progress = (totalDuration.inMilliseconds > 0)
        ? (position.inMilliseconds / totalDuration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 28 : 14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 55 : 30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play / Pause Circle Button
          ShrinkableButton(
            onTap: onTogglePlay,
            child: Container(
              width: compact ? 34 : 40,
              height: compact ? 34 : 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: colors.white,
                size: compact ? 20 : 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Progress Bar / Waveform & Timestamps
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.mic_rounded,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Voice Note',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          totalDuration.inSeconds > 0
                              ? '${formatDuration(position)} / ${formatDuration(totalDuration)}'
                              : formatDuration(position),
                          style: typography.caption.medium.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 6),
                        ShrinkableButton(
                          onTap: onCyclePlaybackRate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(
                                isDark ? 50 : 25,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${playbackRate.toStringAsFixed(playbackRate % 1 == 0 ? 0 : 2)}x',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: colors.primary.withAlpha(
                      isDark ? 40 : 25,
                    ),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Delete button (if in editing/preview mode)
          if (onDelete != null) ...[
            const SizedBox(width: 10),
            ShrinkableButton(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.error.withAlpha(isDark ? 35 : 20),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: colors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
