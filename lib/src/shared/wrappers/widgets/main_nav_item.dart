import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Navigation item definition for Kortex main tabs.
class MainNavItem {
  const MainNavItem({
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.labelBuilder,
  });

  final PageRouteInfo route;
  final IconData icon;
  final IconData activeIcon;
  final String Function(AppLocalizations l10n) labelBuilder;
}

final List<MainNavItem> kNavItems5 = [
  const MainNavItem(
    route: DashboardRoute(),
    icon: Icons.grid_view_rounded,
    activeIcon: Icons.grid_view_rounded,
    labelBuilder: getHomeLabel,
  ),
  const MainNavItem(
    route: DecksRoute(),
    icon: Icons.layers_outlined,
    activeIcon: Icons.layers_rounded,
    labelBuilder: getDecksLabel,
  ),
  const MainNavItem(
    route: CommunityHubRoute(),
    icon: Icons.forum_outlined,
    activeIcon: Icons.forum_rounded,
    labelBuilder: getForumLabel,
  ),
  const MainNavItem(
    route: StudyHubRoute(),
    icon: Icons.hub_outlined,
    activeIcon: Icons.hub_rounded,
    labelBuilder: getStudyHubLabel,
  ),
  const MainNavItem(
    route: ProfileRoute(),
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    labelBuilder: getProfileLabel,
  ),
];

final List<MainNavItem> kNavItems4 = [
  const MainNavItem(
    route: DashboardRoute(),
    icon: Icons.grid_view_rounded,
    activeIcon: Icons.grid_view_rounded,
    labelBuilder: getHomeLabel,
  ),
  const MainNavItem(
    route: DecksRoute(),
    icon: Icons.layers_outlined,
    activeIcon: Icons.layers_rounded,
    labelBuilder: getDecksLabel,
  ),
  const MainNavItem(
    route: StudyHubRoute(),
    icon: Icons.hub_outlined,
    activeIcon: Icons.hub_rounded,
    labelBuilder: getStudyHubLabel,
  ),
  const MainNavItem(
    route: ProfileRoute(),
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    labelBuilder: getProfileLabel,
  ),
];

String getHomeLabel(AppLocalizations l10n) => l10n.navTabHome;
String getDecksLabel(AppLocalizations l10n) => l10n.navTabDecks;
String getForumLabel(AppLocalizations l10n) => l10n.navTabCommunity;
String getStudyHubLabel(AppLocalizations l10n) => l10n.navTabStudyHub;
String getProfileLabel(AppLocalizations l10n) => l10n.navTabProfile;

/// Returns true if the app is currently running on Web or Desktop platforms.
bool get isWebOrDesktop =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;
