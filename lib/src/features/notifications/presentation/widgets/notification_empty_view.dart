import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';

/// Clean state view displayed when a notification filter yields zero items.
class NotificationEmptyView extends StatelessWidget {
  const NotificationEmptyView({
    required this.category,
    required this.onlyUnread,
    super.key,
  });

  final NotificationCategory category;
  final bool onlyUnread;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary.withAlpha(isDark ? 30 : 15),
              ),
              child: Icon(
                onlyUnread
                    ? Icons.mark_email_read_rounded
                    : Icons.notifications_none_rounded,
                size: 34,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              onlyUnread ? 'All Caught Up!' : 'No Notifications',
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              onlyUnread
                  ? "You have reviewed all your unread notifications. We'll alert you when there is new study activity."
                  : 'You do not have any notifications in this category right now.',
              textAlign: TextAlign.center,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
