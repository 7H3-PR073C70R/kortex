import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';

/// Horizontal scrolling row of notification filter chips (All, Unread, Study, Community, Milestones, System).
class NotificationFilterChips extends StatelessWidget {
  const NotificationFilterChips({
    required this.selectedCategory,
    required this.onlyUnread,
    required this.unreadCount,
    required this.onSelectAll,
    required this.onSelectCategory,
    required this.onToggleOnlyUnread,
    super.key,
  });

  final NotificationCategory selectedCategory;
  final bool onlyUnread;
  final int unreadCount;
  final VoidCallback onSelectAll;
  final ValueChanged<NotificationCategory> onSelectCategory;
  final VoidCallback onToggleOnlyUnread;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChipItem(
            label: 'All',
            isSelected:
                selectedCategory == NotificationCategory.all && !onlyUnread,
            onTap: onSelectAll,
          ),
          const SizedBox(width: 8),
          FilterChipItem(
            label: 'Unread',
            count: unreadCount > 0 ? unreadCount : null,
            isSelected: onlyUnread,
            onTap: onToggleOnlyUnread,
          ),
          const SizedBox(width: 8),
          FilterChipItem(
            label: 'Study',
            icon: Icons.auto_stories_rounded,
            isSelected:
                selectedCategory == NotificationCategory.study && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.study),
          ),
          const SizedBox(width: 8),
          FilterChipItem(
            label: 'Community',
            icon: Icons.groups_rounded,
            isSelected:
                selectedCategory == NotificationCategory.community &&
                !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.community),
          ),
          const SizedBox(width: 8),
          FilterChipItem(
            label: 'Milestones',
            icon: Icons.local_fire_department_rounded,
            isSelected:
                selectedCategory == NotificationCategory.streak && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.streak),
          ),
          const SizedBox(width: 8),
          FilterChipItem(
            label: 'System',
            icon: Icons.notifications_active_rounded,
            isSelected:
                selectedCategory == NotificationCategory.system && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.system),
          ),
        ],
      ),
    );
  }
}

/// An individual animated chip item within the notification category filter bar.
class FilterChipItem extends StatelessWidget {
  const FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
    this.icon,
    this.count,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      selected: isSelected,
      label: count != null ? '$label, $count items' : label,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusPanel,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            onTap();
          },
          borderRadius: AppRadius.radiusPanel,
          splashColor: colors.primary.withAlpha(25),
          highlightColor: colors.primary.withAlpha(15),
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 38, minWidth: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : (isDark
                        ? colors.surfaceSecondary
                        : colors.surfaceSecondary.withAlpha(140)),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 60 : 30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: isSelected ? colors.white : colors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.textPrimary,
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.white.withAlpha(55)
                          : colors.primary,
                      borderRadius: AppRadius.radiusBadge,
                    ),
                    child: Text(
                      '$count',
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
