import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_empty_view.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_filter_chips.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_header.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Main content panel body for the notifications view, handling filtering, refresh, and list display.
class NotificationsPanelBody extends StatelessWidget {
  const NotificationsPanelBody({
    required this.isDrawer,
    super.key,
  });

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    final cubit = context.watch<NotificationsCubit>();
    final state = cubit.state;
    final filtered = state.filteredNotifications;

    return Column(
      children: [
        if (isDesktop)
          NotificationHeader(
            unreadCount: state.unreadCount,
            hasUnread: state.notifications.any((n) => !n.isRead),
            onMarkAllRead: () {
              unawaited(context.read<NotificationsCubit>().markAllAsRead());
            },
            onClose: () {
              if (isDrawer) {
                Navigator.of(context).pop();
              } else {
                unawaited(context.router.maybePop());
              }
            },
          ),

        NotificationFilterChips(
          selectedCategory: state.selectedCategory,
          onlyUnread: state.onlyUnread,
          unreadCount: state.unreadCount,
          onSelectAll: () {
            context.read<NotificationsCubit>().showAll();
          },
          onSelectCategory: (cat) {
            context.read<NotificationsCubit>().selectCategory(cat);
          },
          onToggleOnlyUnread: () {
            context.read<NotificationsCubit>().toggleOnlyUnread();
          },
        ),

        const SizedBox(height: 4),

        Expanded(
          child: filtered.isEmpty
              ? NotificationEmptyView(
                  category: state.selectedCategory,
                  onlyUnread: state.onlyUnread,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await context
                        .read<NotificationsCubit>()
                        .loadNotifications(forceRefresh: true);
                  },
                  color: colors.primary,
                  backgroundColor: isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final notif = filtered[index];
                      final tile = NotificationTile(
                        notification: notif,
                        onTap: () {
                          unawaited(
                            context.read<NotificationsCubit>().markAsRead(
                              notif.id,
                            ),
                          );
                        },
                        onDismiss: () {
                          unawaited(
                            context
                                .read<NotificationsCubit>()
                                .deleteNotification(notif.id),
                          );
                        },
                      );

                      if (index < 6) {
                        return tile
                            .animate(delay: (index * 45).ms)
                            .fadeIn(
                              duration: 200.ms,
                              curve: Curves.easeOut,
                            )
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              duration: 200.ms,
                              curve: Curves.easeOutCubic,
                            );
                      }
                      return tile;
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
