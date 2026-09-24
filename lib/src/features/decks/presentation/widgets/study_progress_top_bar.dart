import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

class StudyProgressTopBar extends StatelessWidget {
  const StudyProgressTopBar({
    required this.currentIndex,
    required this.totalCards,
    required this.elapsedTimeFormatted,
    required this.onClose,
    this.canUndo = false,
    this.onUndo,
    this.onThoughtParkingLot,
    super.key,
  });

  final int currentIndex;
  final int totalCards;
  final String elapsedTimeFormatted;
  final VoidCallback onClose;
  final bool canUndo;
  final VoidCallback? onUndo;
  final VoidCallback? onThoughtParkingLot;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final progress = totalCards == 0
        ? 0.0
        : ((currentIndex + 1) / totalCards).clamp(0.0, 1.0);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Action Group: Exit + Undo
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: colors.textPrimary),
                      tooltip: 'Exit Session',
                      onPressed: onClose,
                    ),
                    if (canUndo && onUndo != null)
                      IconButton(
                        icon: Icon(
                          Icons.undo_rounded,
                          color: colors.primary,
                          size: 20,
                        ),
                        tooltip: 'Undo Last Rating (Cmd+Z / Z)',
                        onPressed: onUndo,
                      ),
                  ],
                ),

                // Card index tracker
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(160)
                        : colors.surfacePrimary.withAlpha(200),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: isDark
                          ? colors.surfaceBorderHighlight.withAlpha(70)
                          : colors.surfaceBorder.withAlpha(130),
                    ),
                  ),
                  child: Text(
                    l10n.studySessionCardIndex(currentIndex + 1, totalCards),
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ),

                // Right Action Group: Thought Parking Lot + Timer Pill
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onThoughtParkingLot != null)
                      IconButton(
                        icon: Icon(
                          Icons.psychology_outlined,
                          color: colors.textSecondary,
                          size: 20,
                        ),
                        tooltip: 'Thought Parking Lot',
                        onPressed: onThoughtParkingLot,
                      ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 45 : 20),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 100 : 60),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            elapsedTimeFormatted,
                            style: typography.footnote.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Animated Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.micro),
              child: Container(
                height: 6,
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(60)
                    : colors.surfaceBorder.withAlpha(120),
                child: AnimatedFractionallySizedBox(
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.syllabotAccent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
