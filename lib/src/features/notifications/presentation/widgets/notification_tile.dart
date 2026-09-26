import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/domain/services/notification_router.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Interactive notification card widget with category badge, unread pulse,
/// relative timestamp, and deep navigation routing.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final NotificationItemEntity notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  IconData _getCategoryIcon(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.study:
        return Icons.auto_stories_rounded;
      case NotificationCategory.community:
        return Icons.groups_rounded;
      case NotificationCategory.streak:
        return Icons.local_fire_department_rounded;
      case NotificationCategory.system:
      case NotificationCategory.all:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getCategoryColor(BuildContext context, NotificationCategory category) {
    final colors = context.colors;
    switch (category) {
      case NotificationCategory.study:
        return colors.primary;
      case NotificationCategory.community:
        return colors.success;
      case NotificationCategory.streak:
        return colors.warning;
      case NotificationCategory.system:
      case NotificationCategory.all:
        return colors.syllabotAccent;
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _handleNavigation(BuildContext context) {
    unawaited(
      const NotificationRouter().handleNotificationNavigation(
        router: context.router,
        notification: notification,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final categoryColor = _getCategoryColor(context, notification.category);
    final categoryIcon = _getCategoryIcon(notification.category);
    final relativeTime = _formatRelativeTime(notification.timestamp);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.error.withAlpha(isDark ? 60 : 40),
          borderRadius: AppRadius.radiusPanel,
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colors.error,
          size: 22,
        ),
      ),
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) => AnimatedScale(
          scale: isHovered ? 1.01 : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          child: ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onTap();
              _handleNavigation(context);
            },
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? (isDark
                        ? colors.surfaceSecondary.withAlpha(120)
                        : colors.surfacePrimary)
                    : (isDark
                        ? colors.surfaceSecondary
                        : colors.surfaceSecondary.withAlpha(180)),
                borderRadius: AppRadius.radiusPanel,
                border: Border.all(
                  color: !notification.isRead
                      ? categoryColor.withAlpha(isDark ? 90 : 50)
                      : (isHovered
                          ? colors.primary.withAlpha(isDark ? 50 : 30)
                          : colors.surfaceBorder.withAlpha(isDark ? 40 : 25)),
                  width: !notification.isRead ? 1.3 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 30 : 8),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Icon Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: categoryColor.withAlpha(isDark ? 40 : 22),
                      border: Border.all(
                        color: categoryColor.withAlpha(isDark ? 80 : 45),
                      ),
                    ),
                    child: Icon(
                      categoryIcon,
                      size: 20,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Notification Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: notification.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              relativeTime,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary.withAlpha(160),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unread indicator dot
                  if (!notification.isRead) ...[
                    const SizedBox(width: 8),
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: categoryColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
