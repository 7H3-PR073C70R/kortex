import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

class StudyProgressTopBar extends StatelessWidget {
  const StudyProgressTopBar({
    required this.currentIndex,
    required this.totalCards,
    required this.elapsedTimeFormatted,
    required this.onClose,
    super.key,
  });

  final int currentIndex;
  final int totalCards;
  final String elapsedTimeFormatted;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final progress = totalCards == 0
        ? 0.0
        : ((currentIndex + 1) / totalCards).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Exit button
            IconButton(
              icon: Icon(Icons.close_rounded, color: colors.textPrimary),
              onPressed: onClose,
            ),

            // Card index tracker
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(160)
                    : colors.surfacePrimary.withAlpha(200),
                borderRadius: BorderRadius.circular(12),
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

            // Timer Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 45 : 20),
                borderRadius: BorderRadius.circular(12),
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

        const SizedBox(height: 10),

        // Animated Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Container(
            height: 6,
            color: isDark
                ? colors.surfaceBorderHighlight.withAlpha(60)
                : colors.surfaceBorder.withAlpha(120),
            child: FractionallySizedBox(
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
    );
  }
}
