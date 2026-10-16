import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive card detailing an enrolled course, syllabus coverage, decks, and study actions.
class CourseDetailedCard extends StatelessWidget {
  const CourseDetailedCard({
    required this.course,
    required this.decks,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onDelete,
    super.key,
  });

  final CuratedCourseEntity course;
  final List<DeckEntity> decks;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasDecks = decks.isNotEmpty;
    final realCoverage = hasDecks
        ? (decks.fold<double>(0, (s, d) => s + d.masteryRate) / decks.length)
              .clamp(0.0, 1.0)
        : 0.0;
    final coveragePercent = (realCoverage * 100).toInt();
    final totalCards = decks.fold<int>(0, (s, d) => s + d.totalCards);

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isHovered
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(180)
                          : colors.surfacePrimary.withAlpha(240))
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(140)
                          : colors.surfacePrimary.withAlpha(210)),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(
                  color: isHovered
                      ? colors.primary.withAlpha(isDark ? 110 : 80)
                      : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder.withAlpha(130)),
                  width: 1.1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Code Pill + Department + Delete
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 50 : 25),
                              borderRadius: BorderRadius.circular(
                                AppRadius.micro,
                              ),
                            ),
                            child: Text(
                              course.courseCode,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            course.department,
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: colors.error.withAlpha(180),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Remove Course',
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    course.title,
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Deck & Card Metadata Pills
                  Row(
                    children: [
                      _MetaPill(
                        icon: Icons.layers_outlined,
                        label: '${decks.length} Decks',
                        colors: colors,
                        typography: typography,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _MetaPill(
                        icon: Icons.style_outlined,
                        label: '$totalCards Cards',
                        colors: colors,
                        typography: typography,
                        isDark: isDark,
                      ),
                      const SizedBox(width: 8),
                      _MetaPill(
                        icon: Icons.access_time_rounded,
                        label:
                            '${decks.where((d) => d.dueCards > 0).length} Due',
                        colors: colors,
                        typography: typography,
                        isDark: isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Coverage Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Syllabus & Material Coverage',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
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
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                    child: Container(
                      height: 4,
                      color: isDark
                          ? colors.surfaceBorderHighlight.withAlpha(50)
                          : colors.surfaceBorder.withAlpha(100),
                      child: FractionallySizedBox(
                        widthFactor: realCoverage.clamp(0.0, 1.0),
                        child: Container(color: colors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Action Buttons Row
                  Row(
                    children: [
                      Expanded(
                        child: ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Open Course',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 13,
                                    color: colors.white,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (decks.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        ShrinkableButton(
                          onTap: () {
                            AppFeedback.light();
                            unawaited(
                              context.router.push(
                                StudySessionRoute(deckId: decks.first.id),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 30 : 16),
                              borderRadius: BorderRadius.circular(
                                AppRadius.card,
                              ),
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 70 : 40,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  size: 15,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Study',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.colors,
    required this.typography,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(80)
            : colors.surfacePrimary.withAlpha(160),
        borderRadius: BorderRadius.circular(AppRadius.micro),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(40)
              : colors.surfaceBorder.withAlpha(80),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: colors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}
