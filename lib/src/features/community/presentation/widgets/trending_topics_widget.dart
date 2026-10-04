import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Represents a trending topic tag in the cohort forum feed.
class TrendingTopicItem {
  const TrendingTopicItem({
    required this.tag,
    required this.postCount,
    required this.activeLearners,
    this.isHot = false,
  });

  final String tag;
  final int postCount;
  final int activeLearners;
  final bool isHot;
}

/// Horizontally scrollable Cohort Trending Topics Panel widget.
class TrendingTopicsWidget extends StatelessWidget {
  const TrendingTopicsWidget({
    required this.onTopicSelected,
    this.selectedTag,
    super.key,
  });

  final ValueChanged<String> onTopicSelected;
  final String? selectedTag;

  static const List<TrendingTopicItem> _defaultTopics = [
    TrendingTopicItem(tag: 'All', postCount: 1420, activeLearners: 86, isHot: true),
    TrendingTopicItem(tag: 'WAEC_Calculus', postCount: 312, activeLearners: 42, isHot: true),
    TrendingTopicItem(tag: 'JAMB_Physics_2026', postCount: 285, activeLearners: 38, isHot: true),
    TrendingTopicItem(tag: 'Organic_Chemistry', postCount: 194, activeLearners: 24),
    TrendingTopicItem(tag: 'Cell_Biology', postCount: 140, activeLearners: 18),
    TrendingTopicItem(tag: 'Economics_Supply', postCount: 98, activeLearners: 12),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _defaultTopics.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = _defaultTopics[index];
          final isSelected = selectedTag != null
              ? selectedTag!.toLowerCase() == item.tag.toLowerCase()
              : index == 0;

          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.selectionClick());
              onTopicSelected(item.tag);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary
                    : isDark
                        ? colors.surfaceSecondary.withAlpha(160)
                        : colors.surfaceSecondary,
                borderRadius: AppRadius.radiusBadge,
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : isDark
                          ? colors.surfaceBorder.withAlpha(40)
                          : colors.surfaceBorder,
                  width: isSelected ? 1.5 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: colors.primary.withAlpha(50),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.isHot && !isSelected) ...[
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 13,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    item.tag == 'All' ? '🔥 All Topics' : '#${item.tag}',
                    style: typography.caption.bold.copyWith(
                      color: isSelected ? colors.white : colors.textPrimary,
                      fontSize: 11.5,
                    ),
                  ),
                  if (item.tag != 'All') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.white.withAlpha(50)
                            : colors.textSecondary.withAlpha(25),
                        borderRadius: AppRadius.radiusMicro,
                      ),
                      child: Text(
                        '${item.postCount}',
                        style: typography.caption.bold.copyWith(
                          color: isSelected ? colors.white : colors.textSecondary,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
