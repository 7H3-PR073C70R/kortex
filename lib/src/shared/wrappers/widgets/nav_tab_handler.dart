import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Centralized Tab Switch Handler & Accessibility Announcement orchestrator.
void handleTabTap(
  BuildContext context,
  TabsRouter tabsRouter,
  int targetIndex,
  String tabLabel,
) {
  if (tabsRouter.activeIndex != targetIndex) {
    unawaited(HapticFeedback.selectionClick());
    tabsRouter.setActiveIndex(targetIndex);

    if (targetIndex == 0 && locator.isRegistered<DashboardBloc>()) {
      locator<DashboardBloc>().add(const DashboardRefreshed());
    } else if (targetIndex == 1 && locator.isRegistered<DecksBloc>()) {
      locator<DecksBloc>().add(const DecksRefreshed());
    }

    unawaited(
      // ignore: deprecated_member_use, backward-compatible a11y announcement
      SemanticsService.announce(
        context.l10n.navTabAnnouncement(tabLabel),
        TextDirection.ltr,
      ),
    );
  } else {
    // If already active, trigger light haptic feedback and pop nested tab stack to root
    unawaited(HapticFeedback.lightImpact());
    try {
      final currentChild = tabsRouter.currentChild;
      if (currentChild != null) {
        final innerStack =
            tabsRouter.innerRouterOf<StackRouter>(currentChild.name);
        if (innerStack != null && innerStack.canPop()) {
          innerStack.popUntilRoot();
        }
      }
    } on Object catch (_) {
      // Safe fallback if tab has no nested stack
    }
  }
}
