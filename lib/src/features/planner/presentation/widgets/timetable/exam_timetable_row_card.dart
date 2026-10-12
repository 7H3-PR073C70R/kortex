import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Interactive assessment card displaying deadline, urgency badge, progress, and actions.
class ExamTimetableRowCard extends StatelessWidget {
  const ExamTimetableRowCard({
    required this.exam,
    required this.index,
    required this.isSelected,
    required this.calculator,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
    required this.onPrimaryAction,
    super.key,
  });

  final ExamEventEntity exam;
  final int index;
  final bool isSelected;
  final CramWorkloadCalculator calculator;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    final formattedDate = DateFormat(
      'EEE, d MMM y • hh:mm a',
    ).format(exam.targetDate);

    final urgency = calculator.getUrgencyLevel(
      exam.daysRemaining,
      type: exam.assessmentType,
    );
    final urgencyColor = switch (urgency) {
      ExamUrgencyLevel.normal => colors.primary,
      ExamUrgencyLevel.warning => colors.warning,
      ExamUrgencyLevel.critical => colors.error,
    };

    final actionLabel = switch (exam.assessmentType) {
      AssessmentType.quiz => l10n.actionPracticeScopedDecks,
      AssessmentType.classTest => l10n.actionStartTestReview,
      _ => l10n.actionOpenMockLobby,
    };

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: 160.ms,
          curve: Curves.easeOutQuint,
          transform: Matrix4.translationValues(0, isHovered ? -2 : 0, 0),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : (isHovered
                        ? colors.primary.withValues(alpha: 0.5)
                        : colors.surfaceBorder.withValues(alpha: 0.6)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: colors.black.withValues(
                        alpha: isDark ? 0.35 : 0.1,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Primary Selection Radio / Check
              InkWell(
                onTap: onSelect,
                borderRadius: AppRadius.radiusMicro,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceSecondary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                  ),
                  child: Icon(
                    Icons.check,
                    size: 14,
                    color: isSelected ? colors.white : colors.transparent,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Type Icon
              Icon(
                exam.assessmentType.icon,
                size: 18,
                color: urgencyColor,
              ),
              const SizedBox(width: 8),

              // Title and Subject
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            exam.examName,
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: urgencyColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            exam.assessmentType.displayName,
                            style: typography.caption.bold.copyWith(
                              color: urgencyColor,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        if (exam.isCompleted) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.success.withValues(alpha: 0.15),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 10, color: colors.success),
                                const SizedBox(width: 3),
                                Text(
                                  exam.achievedScorePercent != null
                                      ? '${exam.achievedScorePercent!.toInt()}%'
                                      : 'Done',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.success,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Edit & Delete Actions
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: isHovered ? colors.primary : colors.textSecondary,
                    ),
                    tooltip: 'Edit Assessment',
                    onPressed: onEdit,
                  );
                },
              ),
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: isHovered
                          ? colors.error
                          : colors.error.withValues(alpha: 0.7),
                    ),
                    tooltip: 'Delete Assessment',
                    onPressed: onDelete,
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.radiusMicro,
                ),
                child: Text(
                  '${(exam.effectiveWeightPercent * 100).toInt()}% weight',
                  style: typography.caption.semiBold.copyWith(
                    color: colors.primary,
                    fontSize: 10.5,
                  ),
                ),
              ),
              if (exam.scopedTopics.isNotEmpty)
                ...exam.scopedTopics.take(3).map((topic) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.surfaceBorder.withValues(alpha: 0.3),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                      child: Text(
                        topic,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                    )),
              if (exam.scopedTopics.length > 3)
                Text(
                  '+${exam.scopedTopics.length - 3} more',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              if (exam.scopedTopics.isEmpty && exam.scopedDeckIds.isNotEmpty)
                Text(
                  '${exam.scopedDeckIds.length} scoped decks',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // Progress and Countdown Strip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                exam.isCompleted
                    ? 'Completed'
                    : exam.formattedSubDailyCountdown,
                style: typography.caption.bold.copyWith(
                  color: exam.isCompleted
                      ? colors.success
                      : (exam.isPast ? colors.textSecondary : urgencyColor),
                ),
              ),
              Text(
                '${exam.masteredCardsCount}/${exam.totalCardsCount} cards (${(exam.completionProgress * 100).toInt()}%)',
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadius.radiusMicro,
            child: LinearProgressIndicator(
              value: exam.completionProgress,
              backgroundColor: colors.surfaceBorder.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation<Color>(
                isSelected
                    ? colors.primary
                    : colors.primary.withValues(alpha: 0.7),
              ),
              minHeight: 5,
            ),
          ),

          const SizedBox(height: 12),

          // Primary CTA Action Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPrimaryAction,
              icon: Icon(
                exam.assessmentType == AssessmentType.quiz
                    ? Icons.bolt_rounded
                    : Icons.play_arrow_rounded,
                size: 15,
                color: colors.primary,
              ),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                side: BorderSide(color: colors.primary.withAlpha(120)),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusCard,
                ),
                textStyle: typography.caption.bold.copyWith(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ).animate(delay: (index * 60).ms)
      .fadeIn(duration: 250.ms, curve: Curves.easeOut)
      .slideY(begin: 0.05, end: 0, duration: 250.ms, curve: Curves.easeOutQuint);
  }
}
