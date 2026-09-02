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
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

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
  _MainNavItem(
    route: SyllabotChatRoute(),
    icon: Icons.auto_awesome_outlined,
    activeIcon: Icons.auto_awesome_rounded,
    labelBuilder: _getSyllabotLabel,
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
String _getSyllabotLabel(AppLocalizations l10n) => l10n.navTabSyllabot;
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

    return AutoTabsScaffold(
      routes: _kNavItems.map((item) => item.route).toList(),
      animationDuration: const Duration(milliseconds: 250),
      animationCurve: Curves.easeInOut,
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
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? colors.primary.withAlpha(isDark ? 100 : 70)
                  : Colors.transparent,
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
// iOS Liquid Glass Floating Dock (Draggable Capsule + Visible Page Names)
// ---------------------------------------------------------------------------

class _IOSLiquidGlassDock extends StatefulWidget {
  const _IOSLiquidGlassDock({
    required this.tabsRouter,
  });

  final TabsRouter tabsRouter;

  @override
  State<_IOSLiquidGlassDock> createState() => _IOSLiquidGlassDockState();
}

class _IOSLiquidGlassDockState extends State<_IOSLiquidGlassDock> {
  double? _dragAlignment;
  bool _isDragging = false;
  int? _highlightedIndex;

  int get _lastIndex => _kNavItems.length - 1;

  double _getAlignment(int index) {
    if (_lastIndex == 0) return 0;
    return -1.0 + (index * 2 / _lastIndex);
  }

  void _updateHighlightedIndex() {
    if (!_isDragging || _dragAlignment == null) {
      _highlightedIndex = null;
      return;
    }

    final normalized = ((_dragAlignment! + 1) / 2).clamp(0.0, 1.0);
    final index = (normalized * _lastIndex).round().clamp(0, _lastIndex);
    if (_highlightedIndex != index) {
      _highlightedIndex = index;
      unawaited(HapticFeedback.selectionClick());
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final currentActiveIndex = _isDragging
        ? (_highlightedIndex ?? widget.tabsRouter.activeIndex)
        : widget.tabsRouter.activeIndex;

    const dockHeight = 64.0;

    return Semantics(
      container: true,
      label: l10n.navBarSemanticsLabel,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          math.max(10, bottomInset > 0 ? bottomInset : 14),
        ),
        child: Stack(
          children: [
            // Ambient depth shadow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 80 : 18),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: colors.primary.withAlpha(20),
                        blurRadius: 18,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
              ),
            ),

            // Liquid Glass Morphism Layer
            LiquidGlass.withOwnLayer(
              shape: const LiquidRoundedRectangle(borderRadius: 34),
              settings: LiquidGlassSettings(
                blur: 24,
                glassColor: isDark
                    ? colors.surfaceSecondary.withAlpha(165)
                    : colors.surfacePrimary.withAlpha(225),
                lightIntensity: isDark ? 0.45 : 0.7,
                refractiveIndex: 1.45,
              ),
              child: Container(
                height: dockHeight,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(90)
                        : colors.surfaceBorder.withAlpha(190),
                    width: 1.2,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth =
                        constraints.maxWidth / _kNavItems.length;
                    final totalDragWidth = constraints.maxWidth - itemWidth;

                    return GestureDetector(
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isDragging = true;
                          _dragAlignment =
                              _getAlignment(widget.tabsRouter.activeIndex);
                          _updateHighlightedIndex();
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        if (!_isDragging || totalDragWidth <= 0) return;
                        setState(() {
                          final deltaAlignment =
                              (details.primaryDelta! / totalDragWidth) * 2.0;
                          _dragAlignment = (_dragAlignment! + deltaAlignment)
                              .clamp(-1.0, 1.0);
                          _updateHighlightedIndex();
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        setState(() {
                          _isDragging = false;
                          final currentA = _dragAlignment ??
                              _getAlignment(widget.tabsRouter.activeIndex);
                          final normalized =
                              ((currentA + 1) / 2).clamp(0.0, 1.0);
                          final targetIndex = (normalized * _lastIndex)
                              .round()
                              .clamp(0, _lastIndex);
                          _highlightedIndex = null;
                          _dragAlignment = null;

                          final label =
                              _kNavItems[targetIndex].labelBuilder(l10n);
                          _handleTabTap(
                            context,
                            widget.tabsRouter,
                            targetIndex,
                            label,
                          );
                        });
                      },
                      onHorizontalDragCancel: () {
                        setState(() {
                          _isDragging = false;
                          _highlightedIndex = null;
                          _dragAlignment = null;
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Draggable Liquid Selection Capsule
                          AnimatedAlign(
                            duration: _isDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment(
                              _isDragging
                                  ? (_dragAlignment ??
                                      _getAlignment(
                                        widget.tabsRouter.activeIndex,
                                      ))
                                  : _getAlignment(
                                      widget.tabsRouter.activeIndex,
                                    ),
                              0,
                            ),
                            child: Container(
                              width: itemWidth,
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colors.primary
                                        .withAlpha(isDark ? 55 : 35),
                                    colors.primary
                                        .withAlpha(isDark ? 30 : 15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: colors.primary
                                      .withAlpha(isDark ? 110 : 80),
                                  width: 1.1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary
                                        .withAlpha(isDark ? 50 : 25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Nav Items with Persistent Page Names
                          Row(
                            children:
                                List.generate(_kNavItems.length, (index) {
                              final item = _kNavItems[index];
                              final isSelected = currentActiveIndex == index;
                              final label = item.labelBuilder(l10n);

                              return Expanded(
                                child: Semantics(
                                  button: true,
                                  selected: isSelected,
                                  label: l10n.navTabSemantics(
                                    label,
                                    index + 1,
                                    _kNavItems.length,
                                  ),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _handleTabTap(
                                      context,
                                      widget.tabsRouter,
                                      index,
                                      label,
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          AnimatedScale(
                                            scale: isSelected ? 1.12 : 1.0,
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            curve: Curves.easeOutBack,
                                            child: Icon(
                                              isSelected
                                                  ? item.activeIcon
                                                  : item.icon,
                                              size: 22,
                                              color: isSelected
                                                  ? colors.primary
                                                  : colors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          // Page Name / Label (Always Visible)
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            style: isSelected
                                                ? typography.caption.bold
                                                    .copyWith(
                                                    color: colors.primary,
                                                    fontSize: 10,
                                                    height: 1.1,
                                                  )
                                                : typography.caption.medium
                                                    .copyWith(
                                                    color:
                                                        colors.textSecondary,
                                                    fontSize: 10,
                                                    height: 1.1,
                                                  ),
                                            child: Text(
                                              label,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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
              color: Colors.black.withAlpha(isDark ? 60 : 15),
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
                      : Colors.transparent,
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
