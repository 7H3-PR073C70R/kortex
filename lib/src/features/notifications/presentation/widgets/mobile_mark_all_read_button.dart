import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';

/// Action button shown in the mobile app bar when there are unread notifications.
class MobileMarkAllReadButton extends StatelessWidget {
  const MobileMarkAllReadButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final cubit = context.watch<NotificationsCubit>();
    final state = cubit.state;

    if (!state.notifications.any((n) => !n.isRead)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusBadge,
        child: InkWell(
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            unawaited(context.read<NotificationsCubit>().markAllAsRead());
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
                  : colors.surfaceSecondary.withAlpha(120),
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
                  size: 15,
                  color: colors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Mark all read',
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
