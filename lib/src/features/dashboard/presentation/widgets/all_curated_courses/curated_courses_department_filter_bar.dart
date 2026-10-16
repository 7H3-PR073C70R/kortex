import 'package:flutter/material.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Horizontal department/stream filter selector bar.
class CuratedCoursesDepartmentFilterBar extends StatelessWidget {
  const CuratedCoursesDepartmentFilterBar({
    required this.departments,
    required this.selectedFilter,
    required this.onSelectFilter,
    required this.colors,
    required this.typography,
    required this.isDark,
    super.key,
  });

  final Set<String> departments;
  final String selectedFilter;
  final ValueChanged<String> onSelectFilter;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (departments.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: departments.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dept = departments.elementAt(index);
          final isSelected = selectedFilter == dept;
          return ShrinkableButton(
            onTap: () {
              AppFeedback.selection();
              onSelectFilter(dept);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(100)
                          : colors.surfacePrimary.withAlpha(160)),
                borderRadius: BorderRadius.circular(AppRadius.badge),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(50)
                            : colors.surfaceBorder.withAlpha(120)),
                ),
              ),
              child: Text(
                dept,
                style: typography.caption.bold.copyWith(
                  color: isSelected ? colors.white : colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
