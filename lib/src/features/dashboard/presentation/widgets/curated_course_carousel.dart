import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CuratedCourseCarousel extends StatelessWidget {
  const CuratedCourseCarousel({
    required this.courses,
    super.key,
  });

  final List<CuratedCourseEntity> courses;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    if (courses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.dashboardCuratedCourses,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 16.5,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                l10n.dashboardActiveCoursesCount(courses.length),
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Carousel List
        SizedBox(
          height: 160,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: courses.length,
            separatorBuilder: (context, index) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final course = courses[index];
              return _CourseCard(
                course: course,
                colors: colors,
                isDark: isDark,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.colors,
    required this.isDark,
  });

  final CuratedCourseEntity course;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final l10n = context.l10n;
    final coveragePercent = (course.syllabusCoverage * 100).toInt();

    return Semantics(
      button: true,
      label: '${course.courseCode} ${course.title}. '
          '${l10n.dashboardResourcesCount(course.totalMaterials)}.',
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(
            context.router.push(
              CourseModuleRoute(
                courseId: course.id,
                courseCode: course.courseCode,
                courseTitle: course.title,
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(160)
                    : colors.surfacePrimary.withAlpha(210),
                border: Border.all(
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(70)
                      : colors.surfaceBorder.withAlpha(140),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Code Pill & Past paper indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 60 : 30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.courseCode,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (course.hasActivePastPapers)
                        Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: colors.success,
                        ),
                    ],
                  ),

                  // Title
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                      height: 1.25,
                    ),
                  ),

                  // Bottom Coverage & Material Count
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.dashboardResourcesCount(course.totalMaterials),
                            style: typography.footnote.medium.copyWith(
                              color: isDark
                                  ? colors.textSecondary
                                  : colors.textPrimary.withAlpha(180),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$coveragePercent%',
                            style: typography.footnote.bold.copyWith(
                              color: colors.primary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 4,
                          color: isDark
                              ? colors.surfaceBorderHighlight.withAlpha(50)
                              : colors.surfaceBorder.withAlpha(100),
                          child: FractionallySizedBox(
                            widthFactor:
                                course.syllabusCoverage.clamp(0.1, 1.0),
                            child: Container(
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
