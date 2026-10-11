import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';

/// Subject & Syllabus Mastery Breakdown Card.
class AnalyticsSubjectMasteryCard extends StatelessWidget {
  const AnalyticsSubjectMasteryCard({
    required this.courses,
    required this.colors,
    required this.isDark,
    super.key,
  });

  final List<CuratedCourseEntity> courses;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(140),
              width: 1.2,
            ),
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
                        Icons.school_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Course Mastery Matrix',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${courses.length} Enrolled',
                    style: typography.caption.medium.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (courses.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(
                        Icons.library_books_rounded,
                        size: 28,
                        color: colors.textSecondary.withAlpha(120),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No enrolled courses yet',
                        style: typography.footnote.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Import a syllabus or course materials to '
                        'track mastery',
                        textAlign: TextAlign.center,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...courses.map((course) {
                  final percent = (course.syllabusCoverage * 100).toInt();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
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
                                      AppRadius.micro,
                                    ),
                                  ),
                                  child: Text(
                                    course.courseCode,
                                    style: typography.footnote.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    course.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.footnote.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$percent%',
                            style: typography.footnote.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppRadius.micro,
                              ),
                              child: Container(
                                height: 6,
                                color: isDark
                                    ? colors.surfaceBorderHighlight.withAlpha(
                                        40,
                                      )
                                    : colors.surfaceBorder.withAlpha(80),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: course.syllabusCoverage.clamp(
                                    0.05,
                                    1.0,
                                  ),
                                  child: Container(color: colors.primary),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${course.totalMaterials} materials',
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
