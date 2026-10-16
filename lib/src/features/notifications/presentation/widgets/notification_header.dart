import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Top header bar for the notifications panel with unread badge, "Mark all read", and close button.
class NotificationHeader extends StatelessWidget {
  const NotificationHeader({
    required this.unreadCount,
    required this.hasUnread,
    required this.onMarkAllRead,
    required this.onClose,
    super.key,
  });

  final int unreadCount;
  final bool hasUnread;
  final VoidCallback onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Notifications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary,
                          borderRadius: AppRadius.radiusBadge,
                        ),
                        child: Text(
                          '$unreadCount new',
                          style: typography.caption.bold.copyWith(
                            color: colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasUnread) ...[
                Material(
                  color: Colors.transparent,
                  borderRadius: AppRadius.radiusBadge,
                  child: InkWell(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      onMarkAllRead();
                    },
                    borderRadius: AppRadius.radiusBadge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceSecondary.withAlpha(140),
                        borderRadius: AppRadius.radiusBadge,
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mark all read',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              PlatformHoverBuilder(
                builder: (context, isHovered, child) => AnimatedScale(
                  scale: isHovered ? 1.08 : 1.0,
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  child: child,
                ),
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textMuted,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    tooltip: 'Close notifications',
                    onPressed: onClose,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          color: colors.surfaceBorder.withAlpha(isDark ? 70 : 40),
          height: 1,
          thickness: 1,
        ),
      ],
    );
  }
}

/// Container frame for desktop notification drawer side panel.
class DesktopNotificationDrawerPanel extends StatelessWidget {
  const DesktopNotificationDrawerPanel({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return Container(
      width: 480,
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        border: Border(
          left: BorderSide(
            color: colors.surfaceBorder.withAlpha(isDark ? 90 : 50),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 100 : 40),
            blurRadius: 32,
            offset: const Offset(-8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: child,
      ),
    );
  }
}
