import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/mobile_mark_all_read_button.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_header.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notifications_panel_body.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

NotificationsCubit _resolveNotificationsCubit() =>
    locator.isRegistered<NotificationsCubit>()
        ? locator<NotificationsCubit>()
        : NotificationsCubit();

@RoutePage()
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({
    super.key,
    this.isDrawer = false,
    this.notificationsCubit,
  });

  final bool isDrawer;
  final NotificationsCubit? notificationsCubit;

  /// Helper to open notifications adaptively.
  /// On Desktop/Web (large screen): Slides in as a side drawer panel on the right (480px width)
  /// leaving the left content visible behind a translucent barrier.
  /// On Mobile: Pushes the NotificationsRoute page.
  static Future<void> show(
    BuildContext context, {
    NotificationsCubit? notificationsCubit,
  }) {
    final cubit = notificationsCubit ?? _resolveNotificationsCubit();
    if (AppAdaptiveSheet.isDesktopOrWeb(context)) {
      return AppAdaptiveSheet.showSideDrawer<void>(
        context: context,
        builder: (sheetContext) => BlocProvider<NotificationsCubit>.value(
          value: cubit,
          child: NotificationsPage(
            isDrawer: true,
            notificationsCubit: cubit,
          ),
        ),
      );
    }

    return context.router.push(NotificationsRoute());
  }

  @override
  Widget build(BuildContext context) {
    final cubit = notificationsCubit ?? _resolveNotificationsCubit();
    return BlocProvider<NotificationsCubit>.value(
      value: cubit,
      child: _NotificationsView(isDrawer: isDrawer),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView({required this.isDrawer});

  final bool isDrawer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    if (isDesktop) {
      if (isDrawer) {
        return const DesktopNotificationDrawerPanel(
          child: NotificationsPanelBody(isDrawer: true),
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
                child: DesktopNotificationDrawerPanel(
                  child: NotificationsPanelBody(isDrawer: false),
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
          MobileMarkAllReadButton(),
        ],
      ),
      body: const NotificationsPanelBody(isDrawer: false),
    );
  }
}
