import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Card calculating and presenting total estimated study workload and recommended daily pace.
class AssessmentWorkloadCalculationCard extends StatelessWidget {
  const AssessmentWorkloadCalculationCard({
    required this.isCalculatingWorkload,
    required this.totalWorkload,
    required this.deckCardsCount,
    required this.scopedDecksCount,
    required this.pastQuestionsCount,
    required this.dailyTarget,
    super.key,
  });

  final bool isCalculatingWorkload;
  final int totalWorkload;
  final int deckCardsCount;
  final int scopedDecksCount;
  final int pastQuestionsCount;
  final int dailyTarget;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 30 : 15),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 80 : 40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_graph_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.estimatedExamWorkload,
                style: typography.callout.bold.copyWith(
                  color: colors.primary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (isCalculatingWorkload)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      colors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            totalWorkload > 0
                ? l10n.examTotalStudyItems(totalWorkload)
                : l10n.examNoStudyItems,
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pastQuestionsCount > 0
                ? '• $deckCardsCount flashcards in $scopedDecksCount scoped topics\n• $pastQuestionsCount practice questions included'
                : '• $deckCardsCount flashcards in $scopedDecksCount scoped topics',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.recommendedDailyPaceLabel,
                style: typography.footnote.medium.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 60 : 30),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  l10n.dailyTargetPace(dailyTarget),
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
