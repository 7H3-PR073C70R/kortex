import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Enumeration of primary application main navigation tabs.
enum AppMainTab {
  home,
  decks,
  forum,
  hub,
  profile,
}

/// Enumeration of Study Hub sub-tabs.
///
/// The enum order defines the stable *logical* index used by callbacks
/// (e.g. the guided tour). [forum] is appended last so existing indices
/// stay valid; its visual position is resolved via [AppTabNavigation.hubSubTabs].
enum StudyHubSubTab {
  liveRooms,
  studyCircles,
  marketplace,
  forum,
}

/// Callback definition for sub-tab navigation handlers inside nested pages.
typedef SubTabNavigationHandler = void Function(int subTabIndex);

/// Centralized responsive navigation & tab index resolution service.
///
/// Matrix:
/// - Main Navigation Tabs (5): Home (0), Decks (1), Forum (2), Hub (3), Profile (4)
/// - Compact Dock (4): Home, Decks, Hub (hosts Forum), Profile
/// - Hub Sub-Tabs (wide, 3): Live Rooms, Study Pods, Marketplace
/// - Hub Sub-Tabs (compact, 4): Forum, Live Rooms, Study Pods, Marketplace
class AppTabNavigation {
  const AppTabNavigation._();

  /// Screen width breakpoint separating desktop rail layout from compact layouts.
  static const double desktopBreakpoint = 1024;

  /// Global callback hook for dynamically setting the Study Hub sub-tab.
  /// Receives a logical [StudyHubSubTab] index (enum order).
  static SubTabNavigationHandler? onSelectStudyHubSubTab;

  /// Sub-tab requested before the Study Hub was mounted; consumed on mount.
  static StudyHubSubTab? pendingHubSubTab;

  /// Ordered Study Hub sub-tabs for the given layout.
  ///
  /// On compact layouts the dock has no Forum item, so Forum lives inside Hub.
  static List<StudyHubSubTab> hubSubTabs({required bool isWide}) {
    return (isWide || kIsWeb)
        ? const [
            StudyHubSubTab.liveRooms,
            StudyHubSubTab.studyCircles,
            StudyHubSubTab.marketplace,
          ]
        : const [
            StudyHubSubTab.forum,
            StudyHubSubTab.liveRooms,
            StudyHubSubTab.studyCircles,
            StudyHubSubTab.marketplace,
          ];
  }

  /// Resolves the TabController position for [subTab], or `null` if the
  /// sub-tab is not shown in the current layout.
  static int? hubTabControllerIndex(
    StudyHubSubTab subTab, {
    required bool isWide,
  }) {
    final index = hubSubTabs(isWide: isWide).indexOf(subTab);
    return index < 0 ? null : index;
  }

  /// Returns `true` if the screen width qualifies for the desktop layout.
  static bool isWideLayout(double screenWidth) {
    return screenWidth >= desktopBreakpoint;
  }

  /// Maps a main AutoTabsRouter route index (0..4) to the dock index (0..3).
  static int mainIndexToDockIndex(int mainRouteIndex, [double? screenWidth]) {
    switch (mainRouteIndex) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Decks
      case 2:
        return 2; // Forum -> maps to Hub dock tab
      case 3:
        return 2; // Hub
      case 4:
        return 3; // Profile
      default:
        return 0;
    }
  }

  /// Maps a visual dock item index (0..3) to the corresponding AutoTabsRouter route index (0..4).
  static int dockIndexToMainIndex(int dockIndex, [double? screenWidth]) {
    switch (dockIndex) {
      case 0:
        return 0; // Home (DashboardRoute)
      case 1:
        return 1; // Decks (DecksRoute)
      case 2:
        return 3; // Hub (StudyHubRoute)
      case 3:
        return 4; // Profile (ProfileRoute)
      default:
        return 0;
    }
  }

  /// Calculates the main navigation tab index based on the requested tab.
  static int getMainTabIndex(AppMainTab tab, [double? screenWidth]) {
    switch (tab) {
      case AppMainTab.home:
        return 0;
      case AppMainTab.decks:
        return 1;
      case AppMainTab.forum:
        return 2;
      case AppMainTab.hub:
        return 3;
      case AppMainTab.profile:
        return 4;
    }
  }

  /// Resolves the corresponding [AppMainTab] from a main navigation index.
  static AppMainTab getMainTabFromIndex(int index, [double? screenWidth]) {
    switch (index) {
      case 0:
        return AppMainTab.home;
      case 1:
        return AppMainTab.decks;
      case 2:
        return AppMainTab.forum;
      case 3:
        return AppMainTab.hub;
      case 4:
        return AppMainTab.profile;
      default:
        return AppMainTab.home;
    }
  }

  /// Calculates the logical sub-tab index (enum order) inside the Study Hub view.
  static int getHubSubTabIndex(StudyHubSubTab subTab, [double? screenWidth]) {
    return subTab.index;
  }

  /// Centralized function for switching tabs across the application with responsive routing.
  ///
  /// On compact layouts, [AppMainTab.forum] is redirected to the Hub's Forum sub-tab.
  static void navigateTo(
    BuildContext context,
    AppMainTab targetTab, {
    StudyHubSubTab? subTab,
  }) {
    final isWide = isWideLayout(MediaQuery.sizeOf(context).width);

    var resolvedTab = targetTab;
    var resolvedSubTab = subTab;
    if (targetTab == AppMainTab.forum && !isWide) {
      resolvedTab = AppMainTab.hub;
      resolvedSubTab = StudyHubSubTab.forum;
    }

    AutoTabsRouter.of(context).setActiveIndex(getMainTabIndex(resolvedTab));

    if (resolvedTab == AppMainTab.hub && resolvedSubTab != null) {
      final handler = onSelectStudyHubSubTab;
      if (handler != null) {
        handler(getHubSubTabIndex(resolvedSubTab));
      } else {
        pendingHubSubTab = resolvedSubTab;
      }
    }
  }
}
