import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class CourseModuleHeaderBanner extends StatelessWidget {
  const CourseModuleHeaderBanner({
    required this.courseCode,
    required this.courseTitle,
    required this.examCategory,
    required this.deckCount,
    required this.cardCount,
    required this.dueCount,
    required this.isDark,
    super.key,
  });

  final String courseCode;
  final String courseTitle;
  final ExamCategory examCategory;
  final int deckCount;
  final int cardCount;
  final int dueCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.panel),
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
                color: colors.black.withAlpha(isDark ? 50 : 12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
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
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                    ),
                    child: Text(
                      courseCode,
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(140)
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.micro),
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      examCategory.displayName,
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                courseTitle,
                style: typography.title2.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 20,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 16),

              // Metrics Row with responsive Expanded wrapping
              Row(
                children: [
                  Expanded(
                    child: CourseModuleHeaderMetric(
                      label: 'Study Decks',
                      value: '$deckCount',
                      icon: Icons.layers_outlined,
                      colors: colors,
                      typography: typography,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CourseModuleHeaderMetric(
                      label: 'Flashcards',
                      value: '$cardCount',
                      icon: Icons.style_outlined,
                      colors: colors,
                      typography: typography,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CourseModuleHeaderMetric(
                      label: 'Due Today',
                      value: '$dueCount',
                      icon: Icons.alarm_outlined,
                      colors: colors,
                      typography: typography,
                      isAlert: dueCount > 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CourseModuleHeaderMetric extends StatelessWidget {
  const CourseModuleHeaderMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    required this.typography,
    this.isAlert = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isAlert;

  @override
  Widget build(BuildContext context) {
    final iconColor = isAlert ? colors.error : colors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 5),
            Text(
              value,
              style: typography.callout.bold.copyWith(
                color: isAlert ? colors.error : colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 10.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
