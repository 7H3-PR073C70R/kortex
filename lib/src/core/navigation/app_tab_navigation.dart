import 'package:auto_route/auto_route.dart';
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
enum StudyHubSubTab {
  forum,
  liveRooms,
  studyCircles,
  marketplace,
}

/// Callback definition for sub-tab navigation handlers inside nested pages.
typedef SubTabNavigationHandler = void Function(int subTabIndex);

/// Centralized responsive navigation & tab index resolution service.
///
/// Matrix:
/// - Wide Screens (`width >= 1024`):
///   - Main Dock Items (5): Home (0), Decks (1), Forum (2), Hub (3), Profile (4)
///   - Hub Sub-Tabs (3): Live Rooms (0), Study Circles (1), Marketplace (2)
/// - Compact Screens (`width < 1024`):
///   - Main Dock Items (4): Home (0), Decks (1), Hub (2), Profile (3)
///   - Hub Sub-Tabs (4): Forum (0), Live Rooms (1), Study Circles (2), Marketplace (3)
class AppTabNavigation {
  const AppTabNavigation._();

  /// Screen width breakpoint separating 5-item main nav layout from 4-item layout.
  static const double desktopBreakpoint = 1024;

  /// Global callback hook for dynamically setting the Study Hub sub-tab.
  static SubTabNavigationHandler? onSelectStudyHubSubTab;

  /// Returns `true` if the screen width qualifies for the 5-item main nav layout.
  static bool isWideLayout(double screenWidth) {
    return screenWidth >= desktopBreakpoint;
  }

  /// Maps a main AutoTabsRouter route index (0..4) to the visual dock item index (0..3 or 0..4).
  static int mainIndexToDockIndex(int mainRouteIndex, double screenWidth) {
    if (isWideLayout(screenWidth)) {
      return mainRouteIndex.clamp(0, 4);
    }
    // Compact mapping (4 items):
    // 0 (DashboardRoute) -> 0 (Home)
    // 1 (DecksRoute)     -> 1 (Decks)
    // 2 (CommunityRoute) -> 2 (Hub, since Forum is inside Hub on compact)
    // 3 (StudyHubRoute)  -> 2 (Hub)
    // 4 (ProfileRoute)   -> 3 (Profile)
    switch (mainRouteIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
      case 3:
        return 2;
      case 4:
        return 3;
      default:
        return 0;
    }
  }

  /// Maps a visual dock item index to the corresponding AutoTabsRouter route index (0..4).
  static int dockIndexToMainIndex(int dockIndex, double screenWidth) {
    if (isWideLayout(screenWidth)) {
      return dockIndex.clamp(0, 4);
    }
    // Compact mapping:
    // Dock 0 (Home)    -> AutoTabsRouter index 0 (DashboardRoute)
    // Dock 1 (Decks)   -> AutoTabsRouter index 1 (DecksRoute)
    // Dock 2 (Hub)     -> AutoTabsRouter index 3 (StudyHubRoute)
    // Dock 3 (Profile) -> AutoTabsRouter index 4 (ProfileRoute)
    switch (dockIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 3;
      case 3:
        return 4;
      default:
        return 0;
    }
  }

  /// Calculates the main navigation tab index based on the screen width and requested tab.
  static int getMainTabIndex(AppMainTab tab, double screenWidth) {
    final isWide = isWideLayout(screenWidth);

    switch (tab) {
      case AppMainTab.home:
        return 0;
      case AppMainTab.decks:
        return 1;
      case AppMainTab.forum:
        return isWide ? 2 : 3; // On compact, Forum navigates to StudyHubRoute (3)
      case AppMainTab.hub:
        return isWide ? 3 : 3;
      case AppMainTab.profile:
        return 4;
    }
  }

  /// Resolves the corresponding [AppMainTab] from a main navigation index and screen width.
  static AppMainTab getMainTabFromIndex(int index, double screenWidth) {
    final isWide = isWideLayout(screenWidth);

    if (isWide) {
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
    } else {
      switch (index) {
        case 0:
          return AppMainTab.home;
        case 1:
          return AppMainTab.decks;
        case 2:
        case 3:
          return AppMainTab.hub;
        case 4:
          return AppMainTab.profile;
        default:
          return AppMainTab.home;
      }
    }
  }

  /// Calculates the sub-tab index inside the Study Hub view.
  static int getHubSubTabIndex(StudyHubSubTab subTab, double screenWidth) {
    final isWide = isWideLayout(screenWidth);

    switch (subTab) {
      case StudyHubSubTab.forum:
        return 0; // Only present on compact screens
      case StudyHubSubTab.liveRooms:
        return isWide ? 0 : 1;
      case StudyHubSubTab.studyCircles:
        return isWide ? 1 : 2;
      case StudyHubSubTab.marketplace:
        return isWide ? 2 : 3;
    }
  }

  /// Centralized function for switching tabs across the application with responsive routing.
  static void navigateTo(
    BuildContext context,
    AppMainTab targetTab, {
    StudyHubSubTab? subTab,
  }) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = isWideLayout(screenWidth);
    final targetMainIndex = getMainTabIndex(targetTab, screenWidth);

    AutoTabsRouter.of(context).setActiveIndex(targetMainIndex);

    // Handle sub-tab selection for Hub / Forum context
    if (targetTab == AppMainTab.forum && !isWide) {
      final hubSubIndex = getHubSubTabIndex(StudyHubSubTab.forum, screenWidth);
      onSelectStudyHubSubTab?.call(hubSubIndex);
    } else if (targetTab == AppMainTab.hub && subTab != null) {
      final hubSubIndex = getHubSubTabIndex(subTab, screenWidth);
      onSelectStudyHubSubTab?.call(hubSubIndex);
    }
  }
}
