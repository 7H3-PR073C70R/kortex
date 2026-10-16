import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Selectable course tile displaying course code, title, department, and selection status.
class CourseSelectTile extends StatelessWidget {
  const CourseSelectTile({
    required this.course,
    required this.isSelected,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onToggle,
    super.key,
  });

  final CuratedCourseEntity course;
  final bool isSelected;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${course.courseCode} ${course.title}. ${isSelected ? "Selected" : "Not selected"}',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withAlpha(isDark ? 40 : 25)
                    : isHovered
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(180)
                          : colors.surfaceSecondary)
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(120)
                          : colors.surfaceSecondary),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : isHovered
                      ? colors.primary.withAlpha(isDark ? 110 : 80)
                      : colors.surfaceBorder.withAlpha(80),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  // Course Code Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : (isDark
                                ? colors.surfacePrimary.withAlpha(200)
                                : colors.surfacePrimary),
                      borderRadius: BorderRadius.circular(AppRadius.badge),
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorder.withAlpha(100),
                      ),
                    ),
                    child: Text(
                      course.courseCode,
                      style: typography.caption.bold.copyWith(
                        color: isSelected ? colors.white : colors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title & Department
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: typography.callout.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          course.department.split('-').last.trim(),
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Selection Checkmark Circle
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colors.primary : colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorderHighlight,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: colors.white,
                            size: 16,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
