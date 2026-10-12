import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Lightweight summary model representing an enrolled or browsable past questions course.
class CourseSummary {
  const CourseSummary({
    required this.title,
    required this.totalQuestions,
    required this.answeredQuestions,
    required this.yearRange,
    required this.iconData,
    this.courseCode,
  });

  final String title;
  final int totalQuestions;
  final int answeredQuestions;
  final String yearRange;
  final IconData iconData;
  final String? courseCode;
}

/// Glassmorphic course overview card on the Past Questions board.
class CourseOverviewCard extends StatelessWidget {
  const CourseOverviewCard({
    required this.courseSummary,
    required this.examCategory,
    this.selectedYear,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  final CourseSummary courseSummary;
  final ExamCategory examCategory;
  final int? selectedYear;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final hasQuestions = courseSummary.totalQuestions > 0;
    final progress = hasQuestions
        ? (courseSummary.answeredQuestions / courseSummary.totalQuestions)
            .clamp(0.0, 1.0)
        : 0.0;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: () {
            AppFeedback.light();
            if (onTap != null) {
              onTap!();
            } else {
              unawaited(
                context.router.push(
                  CourseQuestionsRoute(
                    courseTitle: courseSummary.title,
                    courseCode: courseSummary.courseCode,
                    examCategory: examCategory,
                    initialYear: selectedYear,
                  ),
                ),
              );
            }
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.snappyCurve,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withAlpha(isDark ? 50 : 25)
                  : (isHovered
                      ? (isDark
                          ? colors.surfaceSecondary.withAlpha(245)
                          : colors.surfacePrimary.withAlpha(245))
                      : (isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary)),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : (isHovered
                        ? colors.primary.withAlpha(isDark ? 110 : 70)
                        : colors.primary.withAlpha(isDark ? 50 : 25)),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(
                    isHovered ? (isDark ? 80 : 20) : (isDark ? 60 : 12),
                  ),
                  blurRadius: isHovered ? 14 : 10,
                  offset: Offset(0, isHovered ? 5 : 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Subject Icon Container
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary.withAlpha(isDark ? 60 : 35),
                            colors.primary.withAlpha(isDark ? 30 : 15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: colors.primary.withAlpha(isDark ? 80 : 45),
                        ),
                      ),
                      child: Icon(
                        courseSummary.iconData,
                        color: colors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            courseSummary.title,
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 15.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(
                                    isDark ? 40 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.badge,
                                  ),
                                ),
                                child: Text(
                                  examCategory.displayName,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hasQuestions
                                      ? '${courseSummary.totalQuestions} Questions • ${courseSummary.yearRange}'
                                      : 'Available for AI Practice',
                                  style: typography.caption.medium.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                if (hasQuestions) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colors.primary.withAlpha(
                        isDark ? 30 : 20,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${courseSummary.answeredQuestions} of ${courseSummary.totalQuestions} practiced',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 10.5,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
