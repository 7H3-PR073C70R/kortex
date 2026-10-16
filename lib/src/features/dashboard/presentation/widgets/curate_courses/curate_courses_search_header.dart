import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top section with active track pill, search bar, custom course button, category chips, and quick-add hint.
class CurateCoursesSearchHeader extends StatelessWidget {
  const CurateCoursesSearchHeader({
    required this.userTrack,
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.searchQuery,
    required this.hasNoMatches,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectCategory,
    required this.onOpenAddCustomCourse,
    required this.colors,
    required this.typography,
    required this.isDark,
    super.key,
  });

  final String userTrack;
  final TextEditingController searchController;
  final List<String> categories;
  final String selectedCategory;
  final String searchQuery;
  final bool hasNoMatches;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSelectCategory;
  final VoidCallback onOpenAddCustomCourse;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Track Indicator Badge
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 35 : 20),
              borderRadius: BorderRadius.circular(
                AppRadius.badge,
              ),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 70 : 40),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Active Academic Track: $userTrack',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 1. Search Bar & Add Custom Course Action
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
          child: Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: searchController,
                  hintText: 'Search course code or title...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: colors.textSecondary,
                            size: 18,
                          ),
                          onPressed: onClearSearch,
                        )
                      : null,
                  isDense: true,
                  borderRadius: AppRadius.card,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Add custom subject',
                child: ShrinkableButton(
                  onTap: onOpenAddCustomCourse,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(
                        AppRadius.card,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(
                            isDark ? 50 : 20,
                          ),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Category Filter Chips
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = cat == selectedCategory;
              return ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                selectedColor: colors.primary.withAlpha(
                  isDark ? 60 : 35,
                ),
                backgroundColor: isDark
                    ? colors.surfaceSecondary.withAlpha(120)
                    : colors.surfaceSecondary,
                labelStyle: typography.caption.bold.copyWith(
                  color: isSelected ? colors.primary : colors.textSecondary,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppRadius.badge,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary
                        : colors.surfaceBorder.withAlpha(80),
                  ),
                ),
                onSelected: (_) {
                  unawaited(HapticFeedback.lightImpact());
                  onSelectCategory(cat);
                },
              )
                  .animate(delay: (index * 40).ms)
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
            },
          ),
        ),
        const SizedBox(height: 8),

        // 3. Quick-Add Banner when search has no exact match
        if (searchQuery.trim().isNotEmpty && hasNoMatches) ...[
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 10,
            ),
            child: ShrinkableButton(
              onTap: onOpenAddCustomCourse,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 40 : 25),
                      colors.syllabotAccent.withAlpha(
                        isDark ? 30 : 15,
                      ),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(
                    AppRadius.panel,
                  ),
                  border: Border.all(
                    color: colors.primary.withAlpha(90),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add "$searchQuery" to Curriculum',
                            style: typography.callout.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to provision and track this subject.',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: colors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
