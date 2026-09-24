import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_tile.dart';

@RoutePage()
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NotificationsCubit>.value(
      value: locator.isRegistered<NotificationsCubit>()
          ? locator<NotificationsCubit>()
          : NotificationsCubit(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends HookWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final cubit = context.watch<NotificationsCubit>();
    final state = cubit.state;
    final filtered = state.filteredNotifications;

    return Scaffold(
      backgroundColor: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor:
            isDark ? colors.backgroundPrimary : colors.surfacePrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(context.router.maybePop());
            },
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? colors.surfaceSecondary
                    : colors.surfaceSecondary.withAlpha(140),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: colors.textPrimary,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              'Notifications',
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: typography.caption.bold.copyWith(
                    color: colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.notifications.any((n) => !n.isRead))
            Padding(
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              // Filter Chips Carousel
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

              const SizedBox(height: 8),

              // Notifications Feed
              Expanded(
                child: filtered.isEmpty
                    ? _NotificationEmptyView(
                        category: state.selectedCategory,
                        onlyUnread: state.onlyUnread,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await context.read<NotificationsCubit>().loadNotifications(forceRefresh: true);
                        },
                        color: colors.primary,
                        backgroundColor: isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final notif = filtered[index];
                            final tile = NotificationTile(
                              notification: notif,
                              onTap: () {
                                unawaited(
                                  context
                                      .read<NotificationsCubit>()
                                      .markAsRead(notif.id),
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
            isSelected: selectedCategory == NotificationCategory.all && !onlyUnread,
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
            isSelected: selectedCategory == NotificationCategory.study && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.study),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Community',
            icon: Icons.groups_rounded,
            isSelected: selectedCategory == NotificationCategory.community && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.community),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'Milestones',
            icon: Icons.local_fire_department_rounded,
            isSelected: selectedCategory == NotificationCategory.streak && !onlyUnread,
            onTap: () => onSelectCategory(NotificationCategory.streak),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            label: 'System',
            icon: Icons.notifications_active_rounded,
            isSelected: selectedCategory == NotificationCategory.system && !onlyUnread,
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
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
