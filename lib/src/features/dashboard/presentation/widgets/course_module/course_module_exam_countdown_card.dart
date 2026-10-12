import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CourseModuleExamCountdownCard extends StatelessWidget {
  const CourseModuleExamCountdownCard({
    required this.courseCode,
    required this.courseTitle,
    required this.isDark,
    super.key,
  });

  final String courseCode;
  final String courseTitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return BlocBuilder<CramPlannerCubit, CramPlannerState>(
      builder: (context, plannerState) {
        if (plannerState.status == CramPlannerStatus.initial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(context.read<CramPlannerCubit>().loadExams());
          });
        }
        final cleanCode = courseCode.toLowerCase();
        final cleanTitle = courseTitle.toLowerCase();
        final matchingExams = plannerState.activeExams.where((e) {
          final track = e.subjectTrack.toLowerCase();
          final name = e.examName.toLowerCase();
          return track.contains(cleanCode) ||
              track.contains(cleanTitle) ||
              name.contains(cleanCode) ||
              name.contains(cleanTitle);
        }).toList();

        final matchingExam = matchingExams.firstOrNull;

        if (matchingExam != null) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final target = DateTime(
            matchingExam.targetDate.year,
            matchingExam.targetDate.month,
            matchingExam.targetDate.day,
          );
          final daysLeft = target.difference(today).inDays;
          final formattedDate = DateFormat(
            'MMM d, y',
          ).format(matchingExam.targetDate);

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        colors.primary.withAlpha(50),
                        colors.surfaceSecondary,
                      ]
                    : [
                        colors.primary.withAlpha(25),
                        colors.surfacePrimary,
                      ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 90 : 50),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Center(
                    child: Icon(
                      matchingExam.assessmentType.icon,
                      color: colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              daysLeft == 1
                                  ? '1 Day Until ${matchingExam.assessmentType.displayName}'
                                  : '$daysLeft Days Until ${matchingExam.assessmentType.displayName}',
                              style: typography.callout.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (matchingExams.length > 1) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => ManageExamModalSheet.show(
                                context,
                                scopedCourseCode: courseCode,
                                scopedCourseTitle: courseTitle,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(isDark ? 50 : 25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+${matchingExams.length - 1} more',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${matchingExam.examName} • $formattedDate • ~${matchingExam.dailyTarget} items/day',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ShrinkableButton(
                  onTap: () => ManageExamModalSheet.show(
                    context,
                    scopedCourseCode: courseCode,
                    scopedCourseTitle: courseTitle,
                    initialExamId: matchingExam.id,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 80 : 50),
                      ),
                    ),
                    child: Text(
                      'Manage',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // If no countdown set yet, show an inviting prompt
        return InkWell(
          onTap: () => context.router.push(
            AddAcademicAssessmentRoute(
              preselectedCourseCode: courseCode,
              preselectedCourseTitle: courseTitle,
            ),
          ),
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surfaceSecondary.withAlpha(isDark ? 100 : 70),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(100),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.alarm_add_rounded,
                  size: 20,
                  color: colors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Assessment Countdown',
                        style: typography.callout.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Track quizzes, tests, mid-terms, or final exams with automated pacing',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
