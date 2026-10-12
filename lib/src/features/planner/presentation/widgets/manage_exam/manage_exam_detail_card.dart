import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Card showing rich assessment details, status pills, readiness gauge, and pace.
class ManageExamDetailCard extends StatelessWidget {
  const ManageExamDetailCard({
    required this.exam,
    required this.pace,
    required this.badgeColor,
    super.key,
  });

  final ExamEventEntity exam;
  final int pace;
  final Color badgeColor;

  static const _calculator = CramWorkloadCalculator();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(180)
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: badgeColor.withAlpha(isDark ? 90 : 50),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withAlpha(isDark ? 40 : 25),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      exam.assessmentType.icon,
                      size: 13,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${exam.assessmentType.displayName.toUpperCase()} • ${exam.subjectTrack}',
                      style: typography.caption.bold.copyWith(
                        color: badgeColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${exam.targetDate.year}-${exam.targetDate.month.toString().padLeft(2, '0')}-${exam.targetDate.day.toString().padLeft(2, '0')}',
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            exam.examName,
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (exam.isPostponed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.warning.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.warning.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    exam.originalTargetDate != null
                        ? 'Postponed from ${DateFormat("MMM d").format(exam.originalTargetDate!)}'
                        : 'Postponed',
                    style: typography.caption.bold.copyWith(
                      color: colors.warning,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (exam.isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.error.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.error.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    'Cancelled',
                    style: typography.caption.bold.copyWith(
                      color: colors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
              if (exam.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 50 : 25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.primary.withAlpha(80),
                    ),
                  ),
                  child: Text(
                    'Completed: ${exam.achievedScorePercent != null ? (exam.achievedScorePercent! > 1.0 ? exam.achievedScorePercent! : exam.achievedScorePercent! * 100).toInt() : 100}%',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 11,
                    ),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(exam.effectiveWeightPercent > 1.0 ? exam.effectiveWeightPercent : exam.effectiveWeightPercent * 100).toInt()}% of grade',
                  style: typography.caption.semiBold.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
              if (exam.scopedTopics.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Topics: ${exam.scopedTopics.join(", ")}',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Bimodal Knowledge Calibration & Readiness Gauge
          () {
            final readiness = _calculator.calculateExamReadinessScore(
              totalCards: exam.totalCardsCount,
              masteredCards: exam.masteredCardsCount,
              averageStability: 18,
              daysRemaining: exam.daysRemaining,
              totalLapses: exam.totalLapses,
              empiricalQuizScorePercent: exam.achievedScorePercent,
            );
            final readinessColor = readiness >= 75
                ? colors.success
                : (readiness >= 50 ? colors.warning : colors.error);
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology_outlined,
                            size: 14,
                            color: readinessColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            exam.achievedScorePercent != null
                                ? 'Overall Readiness (Memory & Quiz)'
                                : 'Predicted Memory Retention',
                            style: typography.caption.bold.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${readiness.toInt()}%',
                        style: typography.caption.bold.copyWith(
                          color: readinessColor,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: readiness / 100.0,
                      backgroundColor: colors.surfaceBorder.withAlpha(80),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(readinessColor),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          }(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 15,
                color: badgeColor,
              ),
              const SizedBox(width: 6),
              Text(
                exam.formattedSubDailyCountdown,
                style: typography.footnote.semiBold.copyWith(
                  color: badgeColor,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_graph_rounded,
                size: 15,
                color: colors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.recommendedDailyPace(pace),
                style: typography.footnote.semiBold.copyWith(
                  color: colors.primary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
