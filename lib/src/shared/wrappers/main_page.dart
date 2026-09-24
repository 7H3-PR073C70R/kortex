import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/num_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/ingestion/presentation/widgets/background_ingestion_indicator.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_card.dart';
import 'package:kortex/src/shared/widgets/floating_syllabot_overlay.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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
    icon: Icons.grid_view_rounded,
    activeIcon: Icons.grid_view_rounded,
    labelBuilder: _getHomeLabel,
  ),
  const _MainNavItem(
    route: DecksRoute(),
    icon: Icons.layers_outlined,
    activeIcon: Icons.layers_rounded,
    labelBuilder: _getDecksLabel,
  ),
  const _MainNavItem(
    route: CommunityHubRoute(),
    icon: Icons.chat_bubble_outline,
    activeIcon: Icons.chat_bubble,
    labelBuilder: _getForumLabel,
  ),
  const _MainNavItem(
    route: StudyHubRoute(),
    icon: Icons.device_hub,
    activeIcon: Icons.device_hub_rounded,
    labelBuilder: _getStudyHubLabel,
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
String _getForumLabel(AppLocalizations l10n) => l10n.forumTab;
String _getStudyHubLabel(AppLocalizations l10n) => l10n.navTabStudyHub;
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          AutoTabsScaffold(
            routes: _kNavItems.map((item) => item.route).toList(),
            homeIndex: 0,
            animationDuration: AppMotion.standard,
            animationCurve: AppMotion.easeOutCubic,
            extendBody: true,
            backgroundColor: colors.backgroundPrimary,
            resizeToAvoidBottomInset: false,
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
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 76.height),
                          child: child,
                        ),
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
              return _AdaptiveBottomNavDock(
                tabsRouter: tabsRouter,
              );
            },
          ),
          const BackgroundIngestionIndicator(),
        ],
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
                  borderRadius: AppRadius.radiusPanel,
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(120)
                      : colors.surfaceSecondary.withAlpha(180),
                  border: Border.all(
                    color: colors.surfaceBorder,
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
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.neuralEngineActive,
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
      child: PlatformHoverBuilder(
        builder: (context, isHovered, _) {
          return ShrinkableButton(
            onTap: onTap,
            shrinkScale: 0.98,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusCard,
                color: isSelected
                    ? colors.primary.withAlpha(isDark ? 45 : 25)
                    : (isHovered
                          ? colors.surfaceBorder.withAlpha(isDark ? 35 : 45)
                          : colors.transparent),
                border: Border.all(
                  color: isSelected
                      ? colors.primary.withAlpha(isDark ? 100 : 70)
                      : (isHovered ? colors.surfaceBorder : colors.transparent),
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
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Platform Adaptive Bottom Navigation Dock (< 1024dp)
// iOS/macOS: App Liquid Card (specular refraction, blur, liquid styling)
// Android/Others: Normal Capsule (clean Material 3 tonal container)
// ---------------------------------------------------------------------------

class _AdaptiveBottomNavDock extends StatelessWidget {
  const _AdaptiveBottomNavDock({
    required this.tabsRouter,
  });

  final TabsRouter tabsRouter;

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isApple = _isApplePlatform;

    final dockMargin = EdgeInsets.fromLTRB(
      16,
      0,
      16,
      math.max(12, bottomInset),
    );

    final navContent = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(_kNavItems.length, (index) {
        final item = _kNavItems[index];
        final isSelected = tabsRouter.activeIndex == index;
        final label = item.labelBuilder(l10n);

        return Expanded(
          child: _AdaptiveNavItem(
            icon: item.icon,
            activeIcon: item.activeIcon,
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
          ),
        );
      }),
    );

    if (isApple) {
      // iOS: App Liquid Card with theme-aware specular & blur styling
      return Semantics(
        container: true,
        label: l10n.navBarSemanticsLabel,
        child: Padding(
          padding: dockMargin,
          child: AppLiquidCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            settings: LiquidGlassSettings(
              blur: 24,
              glassColor: isDark
                  ? colors.surfaceSecondary.withAlpha(70)
                  : colors.white.withAlpha(170),
              lightIntensity: isDark ? 0.4 : 0.85,
              refractiveIndex: 1.25,
            ),
            child: navContent,
          ),
        ),
      );
    } else {
      // Android: Normal capsule surface container
      return Semantics(
        container: true,
        label: l10n.navBarSemanticsLabel,
        child: Padding(
          padding: dockMargin,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(235)
                  : colors.surfacePrimary.withAlpha(245),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(60)
                    : colors.surfaceBorder.withAlpha(140),
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 80 : 25),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: navContent,
          ),
        ),
      );
    }
  }
}

class _AdaptiveNavItem extends StatelessWidget {
  const _AdaptiveNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.itemIndex,
    required this.totalItems,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final int itemIndex;
  final int totalItems;
  final VoidCallback onTap;

  // Fixed capsule dimensions across all tabs
  static const double capsuleWidth = 60;
  static const double capsuleHeight = 48;

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
        child: Center(
          child: SizedBox(
            width: capsuleWidth,
            height: capsuleHeight,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withAlpha(isDark ? 45 : 28)
                    : colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? colors.primary.withAlpha(isDark ? 100 : 75)
                      : colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSelected ? activeIcon : icon,
                    size: 20,
                    color: isSelected ? colors.primary : colors.textSecondary,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: typography.caption.medium.copyWith(
                      fontSize: 10,
                      height: 1.1,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
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
