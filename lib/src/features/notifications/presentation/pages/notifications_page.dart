import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

@RoutePage()
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    this.isDrawer = false,
  });

  final bool isDrawer;

  /// Helper to open notifications adaptively.
  /// On Desktop/Web (large screen): Slides in as a side drawer panel on the right (480px width)
  /// leaving the left content visible behind a translucent barrier.
  /// On Mobile: Pushes the NotificationsRoute page.
  static Future<void> show(BuildContext context) {
    if (AppAdaptiveSheet.isDesktopOrWeb(context)) {
      final cubit = locator.isRegistered<NotificationsCubit>()
          ? locator<NotificationsCubit>()
          : NotificationsCubit();

      return AppAdaptiveSheet.showSideDrawer<void>(
        context: context,
        builder: (sheetContext) => BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: const NotificationsPage(isDrawer: true),
        ),
      );
    }

    return context.router.push(NotificationsRoute());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsCubit>.value(
      value: locator.isRegistered<NotificationsCubit>()
          ? locator<NotificationsCubit>()
          : NotificationsCubit(),
      child: _NotificationsView(isDrawer: isDrawer),
    );
  }
}

class _NotificationsView extends HookWidget {
  const _NotificationsView({required this.isDrawer});

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    if (isDesktop) {
      if (isDrawer) {
        return const _DesktopNotificationDrawerPanel(
          child: _NotificationsPanelBody(isDrawer: true),
        );
      } else {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => context.router.maybePop(),
                  child: Container(
                    color: colors.black.withAlpha(isDark ? 160 : 120),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment.centerRight,
                child: _DesktopNotificationDrawerPanel(
                  child: _NotificationsPanelBody(isDrawer: false),
                ),
              )
                  .animate()
                  .slideX(
                    begin: 1,
                    end: 0,
                    duration: 250.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppAdaptiveAppBar(
        backgroundColor: isDark
            ? colors.backgroundPrimary
            : colors.surfacePrimary,
        titleText: 'Notifications',
        breadcrumbs: [
          AppBreadcrumbItem(
            label: 'Dashboard',
            onTap: () => context.router.maybePop(),
          ),
          const AppBreadcrumbItem(label: 'Notifications'),
        ],
        actions: const [
          _MobileMarkAllReadButton(),
        ],
      ),
      body: const _NotificationsPanelBody(isDrawer: false),
    );
  }
}

class _DesktopNotificationDrawerPanel extends StatelessWidget {
  const _DesktopNotificationDrawerPanel({
    required this.child,
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

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({
    required this.unreadCount,
    required this.hasUnread,
    required this.onMarkAllRead,
    required this.onClose,
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
                    Text(
                      'Notifications',
                      style: typography.title3.bold.copyWith(
                        color: colors.textPrimary,
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

class _NotificationsPanelBody extends HookWidget {
  const _NotificationsPanelBody({required this.isDrawer});

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
          _NotificationHeader(
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

        _NotificationFilterChips(
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
              ? _NotificationEmptyView(
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

class _MobileMarkAllReadButton extends StatelessWidget {
  const _MobileMarkAllReadButton();

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

class _NotificationFilterChips extends StatelessWidget {
  const _NotificationFilterChips({
    required this.selectedCategory,
    required this.onlyUnread,
    required this.unreadCount,
    required this.onSelectAll,
    required this.onSelectCategory,
    required this.onToggleOnlyUnread,
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
          _FilterChipItem(
            label: 'All',
            isSelected:
                selectedCategory == NotificationCategory.all && !onlyUnread,
            onTap: onSelectAll,
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Unread',
            count: unreadCount > 0 ? unreadCount : null,
            isSelected: onlyUnread,
            onTap: onToggleOnlyUnread,
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Study',
            icon: Icons.auto_stories_rounded,
            isSelected:
                selectedCategory == NotificationCategory.study && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.study),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Community',
            icon: Icons.groups_rounded,
            isSelected:
                selectedCategory == NotificationCategory.community &&
                !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.community),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Milestones',
            icon: Icons.local_fire_department_rounded,
            isSelected:
                selectedCategory == NotificationCategory.streak && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.streak),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
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

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
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

class _NotificationEmptyView extends StatelessWidget {
  const _NotificationEmptyView({
    required this.category,
    required this.onlyUnread,
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
