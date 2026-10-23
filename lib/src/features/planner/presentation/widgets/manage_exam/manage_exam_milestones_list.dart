import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Interactive list allowing students to switch between multiple tracked milestones
/// and navigate to the full exam timetable.
class ManageExamMilestonesList extends StatelessWidget {
  const ManageExamMilestonesList({
    required this.currentExamId,
    required this.allExams,
    required this.cubit,
    this.scopedCourseCode,
    this.scopedCourseTitle,
    super.key,
  });

  final String currentExamId;
  final List<ExamEventEntity> allExams;
  final CramPlannerCubit cubit;
  final String? scopedCourseCode;
  final String? scopedCourseTitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isScoped = (scopedCourseCode != null && scopedCourseCode!.isNotEmpty) ||
        (scopedCourseTitle != null && scopedCourseTitle!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allExams.length > 1) ...[
          Text(
            isScoped
                ? '${scopedCourseCode ?? scopedCourseTitle} Milestones (${allExams.length})'
                : 'All Tracked Milestones (${allExams.length})',
            style: typography.subhead.bold.copyWith(
              color: colors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...allExams.map((e) {
            final isSelected = e.id == currentExamId;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.radiusCard,
                      color: isSelected
                          ? colors.primary.withAlpha(isDark ? 40 : 20)
                          : (isHovered
                              ? (isDark
                                  ? colors.surfacePrimary.withAlpha(150)
                                  : colors.surfaceSecondary.withAlpha(130))
                              : (isDark
                                  ? colors.surfacePrimary.withAlpha(100)
                                  : colors.surfaceSecondary.withAlpha(80))),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : (isHovered
                                ? colors.primary.withAlpha(120)
                                : colors.surfaceBorder.withAlpha(80)),
                      ),
                    ),
                    child: InkWell(
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        cubit.selectExam(e.id);
                      },
                      borderRadius: AppRadius.radiusCard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 18,
                      color: isSelected
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      e.assessmentType.icon,
                      size: 14,
                      color: isSelected
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.examName,
                        style: typography.body.semiBold.copyWith(
                          color: isSelected
                              ? colors.primary
                              : colors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      '${e.daysRemaining}d left',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
        ],

        // Open Full Timetable Action
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return AnimatedContainer(
              duration: AppMotion.snappy,
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(
                  isHovered ? (isDark ? 80 : 45) : (isDark ? 50 : 25),
                ),
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.primary.withAlpha(
                    isHovered ? 160 : 100,
                  ),
                ),
              ),
              child: InkWell(
                onTap: () {
                  final router = context.router;
                  Navigator.of(context).pop();
                  unawaited(router.push(ExamTimetableRoute()));
                },
                borderRadius: AppRadius.radiusCard,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'View Full Timetable & Pacing',
                style: typography.callout.bold.copyWith(
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
