import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/floating_syllabot_overlay.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Navigation item definition for Kortex main tabs.
class _MainNavItem {
  const _MainNavItem({
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

final List<_MainNavItem> _kNavItems = [
  const _MainNavItem(
    route: DashboardRoute(),
    icon: Icons.dashboard_outlined,
    activeIcon: Icons.dashboard_rounded,
    labelBuilder: _getHomeLabel,
  ),
  const _MainNavItem(
    route: DecksRoute(),
    icon: Icons.style_outlined,
    activeIcon: Icons.style_rounded,
    labelBuilder: _getDecksLabel,
  ),
  const _MainNavItem(
    route: CommunityHubRoute(),
    icon: Icons.people_alt_outlined,
    activeIcon: Icons.people_alt_rounded,
    labelBuilder: _getCommunityLabel,
  ),
  const _MainNavItem(
    route: ProfileRoute(),
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    labelBuilder: _getProfileLabel,
  ),
];

String _getHomeLabel(AppLocalizations l10n) => l10n.navTabHome;
String _getDecksLabel(AppLocalizations l10n) => l10n.navTabDecks;
String _getCommunityLabel(AppLocalizations l10n) => l10n.navTabCommunity;
String _getProfileLabel(AppLocalizations l10n) => l10n.navTabProfile;

/// Main application shell wrapper using [AutoTabsScaffold], responsive
/// desktop navigation rail, and native platform adaptive bottom dock.
@RoutePage()
class MainPage extends HookWidget {
  const MainPage({super.key});

  static const String routeName = '/main';
  static const double desktopBreakpoint = 1024;
  static const double railWidth = 240;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return FloatingSyllabotOverlay(
      child: AutoTabsScaffold(
        routes: _kNavItems.map((item) => item.route).toList(),
        animationDuration: const Duration(milliseconds: 250),
        animationCurve: Curves.easeInOut,
        extendBody: true,
        transitionBuilder: (context, child, animation) {
          final tabsRouter = AutoTabsRouter.of(context);

          return ColoredBox(
            color: colors.backgroundPrimary,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= desktopBreakpoint;

                if (isDesktop) {
                  return Row(
                    children: [
                      _DesktopNavRail(
                        tabsRouter: tabsRouter,
                        width: railWidth,
                      ),
                      VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder,
                      ),
                      Expanded(
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          left: false,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SafeArea(
                  top: false,
                  bottom: false,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
            ),
          );
        },
        bottomNavigationBuilder: (context, tabsRouter) {
          final width = MediaQuery.sizeOf(context).width;
          if (width >= desktopBreakpoint) {
            return const SizedBox.shrink();
          }
          return _AdaptiveBottomNavDock(tabsRouter: tabsRouter);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop Left Navigation Rail (>= 1024dp)
// ---------------------------------------------------------------------------

class _DesktopNavRail extends StatelessWidget {
  const _DesktopNavRail({
    required this.tabsRouter,
    required this.width,
  });

  final TabsRouter tabsRouter;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      container: true,
      label: l10n.navBarSemanticsLabel,
      child: Container(
        width: width,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfacePrimary.withAlpha(200)
              : colors.surfacePrimary.withAlpha(235),
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. App Header Branding
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    AppAssets.svgs.kortexLogo.svg(
                      width: 32,
                      height: 32,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.appName,
                          style: typography.headline.bold.copyWith(
                            color: colors.textPrimary,
                            letterSpacing: 2,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.engineSubtitle,
                          style: typography.caption.bold.copyWith(
                            color: colors.syllabotAccent,
                            fontSize: 9,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. Navigation Items
              Expanded(
                child: ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _kNavItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _kNavItems[index];
                    final isSelected = tabsRouter.activeIndex == index;
                    final label = item.labelBuilder(l10n);

                    return _DesktopNavRailItem(
                      icon: isSelected ? item.activeIcon : item.icon,
                      label: label,
                      isSelected: isSelected,
                      itemIndex: index,
                      totalItems: _kNavItems.length,
                      onTap: () => _handleTabTap(
                        context,
                        tabsRouter,
                        index,
                        label,
                      ),
                    );
                  },
                ),
              ),

              // 3. Desktop Footer Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(120)
                      : colors.surfaceSecondary.withAlpha(180),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(50)
                        : colors.surfaceBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colors.recallEasy,
                        boxShadow: [
                          BoxShadow(
                            color: colors.recallEasy.withAlpha(140),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Neural Engine Active',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavRailItem extends StatelessWidget {
  const _DesktopNavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.itemIndex,
    required this.totalItems,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final int itemIndex;
  final int totalItems;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      selected: isSelected,
      label: l10n.navTabSemantics(label, itemIndex + 1, totalItems),
      child: ShrinkableButton(
        onTap: onTap,
        shrinkScale: 0.98,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isSelected
                ? colors.primary.withAlpha(isDark ? 45 : 25)
                : colors.transparent,
            border: Border.all(
              color: isSelected
                  ? colors.primary.withAlpha(isDark ? 100 : 70)
                  : colors.transparent,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isSelected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: isSelected
                      ? typography.subhead.semiBold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                        )
                      : typography.subhead.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(160),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Adaptive Platform Bottom Navigation Dock (< 1024dp)
// ---------------------------------------------------------------------------

class _AdaptiveBottomNavDock extends StatelessWidget {
  const _AdaptiveBottomNavDock({
    required this.tabsRouter,
  });

  final TabsRouter tabsRouter;

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;

    if (isIOS) {
      return _IOSLiquidGlassDock(tabsRouter: tabsRouter);
    } else if (isAndroid) {
      return _AndroidMaterial3NavBar(tabsRouter: tabsRouter);
    } else {
      // Fallback for macOS, Linux, Windows, Web viewport on smaller screens
      return _IOSLiquidGlassDock(tabsRouter: tabsRouter);
    }
  }
}

// ---------------------------------------------------------------------------
// iOS Liquid Glass Floating Dock (using GlassTabBar.bottom)
// ---------------------------------------------------------------------------

class _IOSLiquidGlassDock extends StatelessWidget {
  const _IOSLiquidGlassDock({
    required this.tabsRouter,
  });

  final TabsRouter tabsRouter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final tabs = _kNavItems.map((item) {
      final label = item.labelBuilder(l10n);
      return GlassTab(
        icon: Icon(item.icon, size: 22),
        activeIcon: Icon(item.activeIcon, size: 22),
        label: label,
        semanticLabel: label,
      );
    }).toList();

    final glassSettings = LiquidGlassSettings(
      thickness: 24,
      blur: 24,
      glassColor: isDark ? const Color(0x351E2430) : const Color(0x75FFFFFF),
      lightIntensity: isDark ? 0.4 : 0.85,
      refractiveIndex: 1.25,
    );

    final indicatorGlassSettings = LiquidGlassSettings(
      thickness: 14,
      blur: 10,
      glassColor: isDark ? const Color(0x40FFFFFF) : const Color(0xF0FFFFFF),
      lightIntensity: isDark ? 0.6 : 0.95,
      refractiveIndex: 1.15,
    );

    return GlassTabBar.bottom(
      tabs: tabs,
      selectedIndex: tabsRouter.activeIndex,
      onTabSelected: (index) {
        final label = _kNavItems[index].labelBuilder(l10n);
        _handleTabTap(context, tabsRouter, index, label);
      },
      settings: glassSettings,
      indicatorSettings: indicatorGlassSettings,
      indicatorColor: isDark
          ? const Color(0x30FFFFFF)
          : const Color(0xEBFFFFFF),
      selectedIconColor: colors.primary,
      unselectedIconColor: colors.textSecondary,
      selectedLabelColor: colors.primary,
      unselectedLabelColor: colors.textSecondary,
      selectedLabelStyle: typography.caption.bold.copyWith(
        color: colors.primary,
        fontSize: 10,
        height: 1.1,
      ),
      unselectedLabelStyle: typography.caption.medium.copyWith(
        color: colors.textSecondary,
        fontSize: 10,
        height: 1.1,
      ),
      horizontalPadding: 16,
      verticalPadding: math.max(10, bottomInset > 0 ? bottomInset : 14),
    );
  }
}

// ---------------------------------------------------------------------------
// Android Material 3 Grounded Navigation Bar
// ---------------------------------------------------------------------------

class _AndroidMaterial3NavBar extends StatelessWidget {
  const _AndroidMaterial3NavBar({
    required this.tabsRouter,
  });

  final TabsRouter tabsRouter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final theme = Theme.of(context);
    final surfaceContainerColor = theme.colorScheme.surfaceContainer;

    return Semantics(
      container: true,
      label: l10n.navBarSemanticsLabel,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceContainerColor,
          border: Border(
            top: BorderSide(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(40)
                  : colors.surfaceBorder.withAlpha(80),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: colors.black.withAlpha(isDark ? 60 : 15),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_kNavItems.length, (index) {
                final item = _kNavItems[index];
                final isSelected = tabsRouter.activeIndex == index;
                final label = item.labelBuilder(l10n);

                return Expanded(
                  child: _AndroidNavBarItem(
                    icon: isSelected ? item.activeIcon : item.icon,
                    label: label,
                    isSelected: isSelected,
                    itemIndex: index,
                    totalItems: _kNavItems.length,
                    colors: colors,
                    typography: typography,
                    isDark: isDark,
                    onTap: () => _handleTabTap(
                      context,
                      tabsRouter,
                      index,
                      label,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _AndroidNavBarItem extends StatelessWidget {
  const _AndroidNavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.itemIndex,
    required this.totalItems,
    required this.colors,
    required this.typography,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final int itemIndex;
  final int totalItems;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Semantics(
      button: true,
      selected: isSelected,
      label: l10n.navTabSemantics(label, itemIndex + 1, totalItems),
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // M3 Active Indicator Pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withAlpha(isDark ? 55 : 30)
                      : colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: isSelected
                    ? typography.caption.semiBold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                      )
                    : typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Centralized Tab Switch Handler & A11y Announcements
// ---------------------------------------------------------------------------

void _handleTabTap(
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
    // If already active, trigger light haptic feedback
    unawaited(HapticFeedback.lightImpact());
  }
}
