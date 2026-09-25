import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:auto_route/auto_route.dart';
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
import 'package:kortex/src/shared/widgets/app_sync_beacon.dart';
import 'package:kortex/src/shared/widgets/floating_syllabot_overlay.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

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
          const AppSyncBeacon(),
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
// World-Leading Floating Liquid Glass Navigation Dock (< 1024dp)
// Authentic Apple Draggable Liquid Glass Physics, Concentric Stadium Capsule,
// Real-time Velocity Jelly Deformation, Specular Refraction, and Ambient Glow
// ---------------------------------------------------------------------------

class _AdaptiveBottomNavDock extends StatefulWidget {
  const _AdaptiveBottomNavDock({
    required this.tabsRouter,
  });

  final TabsRouter tabsRouter;

  @override
  State<_AdaptiveBottomNavDock> createState() => _AdaptiveBottomNavDockState();
}

class _AdaptiveBottomNavDockState extends State<_AdaptiveBottomNavDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late Animation<double> _positionAnimation;

  /// Current indicator position in tab-unit coordinate space (0.0 .. tabCount - 1).
  late double _currentUnitPosition;

  /// Drag state
  bool _isDragging = false;
  double _dragVelocityX = 0;
  int _lastHapticIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentUnitPosition = widget.tabsRouter.activeIndex.toDouble();
    _lastHapticIndex = widget.tabsRouter.activeIndex;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(covariant _AdaptiveBottomNavDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tabsRouter.activeIndex != oldWidget.tabsRouter.activeIndex &&
        !_isDragging) {
      _animateToTab(widget.tabsRouter.activeIndex);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateToTab(int targetIndex) {
    _animController.stop();
    final begin = _currentUnitPosition;
    final end = targetIndex.toDouble();

    _positionAnimation = Tween<double>(begin: begin, end: end).animate(
      CurvedAnimation(
        parent: _animController,
        curve: AppMotion.easeOutCubic,
      ),
    )..addListener(() {
        setState(() {
          _currentUnitPosition = _positionAnimation.value;
        });
      });

    unawaited(_animController.forward(from: 0));
  }

  void _onDragStart(DragStartDetails details, double trackWidth) {
    _animController.stop();
    setState(() {
      _isDragging = true;
      _dragVelocityX = 0;
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double trackWidth) {
    final tabCount = _kNavItems.length;
    final tabWidth = trackWidth / tabCount;
    final deltaUnit = (details.primaryDelta ?? 0) / tabWidth;

    setState(() {
      _dragVelocityX = (details.primaryDelta ?? 0) * 45;
      // Allow slight elastic overscroll at edges (-0.15 .. tabCount - 1 + 0.15)
      _currentUnitPosition = (_currentUnitPosition + deltaUnit).clamp(
        -0.15,
        (tabCount - 1) + 0.15,
      );

      final hoverIndex =
          _currentUnitPosition.round().clamp(0, tabCount - 1);
      if (hoverIndex != _lastHapticIndex) {
        _lastHapticIndex = hoverIndex;
        unawaited(HapticFeedback.selectionClick());
      }
    });
  }

  void _onDragEnd(DragEndDetails details, double trackWidth) {
    final tabCount = _kNavItems.length;
    // Fling velocity adjustment for flick gestures
    final velocityUnit = (details.primaryVelocity ?? 0.0) / 700.0;
    final targetIndex =
        (_currentUnitPosition + velocityUnit * 0.35).round().clamp(0, tabCount - 1);

    setState(() {
      _isDragging = false;
      _dragVelocityX = 0;
      _lastHapticIndex = targetIndex;
    });

    _animateToTab(targetIndex);

    final l10n = context.l10n;
    final label = _kNavItems[targetIndex].labelBuilder(l10n);
    _handleTabTap(context, widget.tabsRouter, targetIndex, label);
  }

  void _onDragCancel() {
    setState(() {
      _isDragging = false;
      _dragVelocityX = 0.0;
    });
    _animateToTab(widget.tabsRouter.activeIndex);
  }

  void _onTabTapped(int index) {
    final l10n = context.l10n;
    final label = _kNavItems[index].labelBuilder(l10n);

    if (widget.tabsRouter.activeIndex == index) {
      _handleTabTap(context, widget.tabsRouter, index, label);
      return;
    }

    _lastHapticIndex = index;
    _animateToTab(index);
    _handleTabTap(context, widget.tabsRouter, index, label);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Floating dock elevation above home indicator
    final dockMargin = EdgeInsets.fromLTRB(
      16,
      0,
      16,
      math.max(14, bottomInset + 4),
    );

    const dockHeight = 66.0;
    const dockRadius = 33.0;
    const capsuleInsetV = 6.0;
    const capsuleInsetH = 4.0;
    const capsuleHeight = dockHeight - (capsuleInsetV * 2); // 54dp
    const capsuleRadius = dockRadius - capsuleInsetV; // 27dp concentric

    // Velocity-based jelly stretch & squash
    final velocityStretch = _isDragging
        ? (_dragVelocityX.abs() * 0.00035).clamp(0.0, 0.22)
        : 0.0;
    final jellyScaleX = 1.0 + velocityStretch;
    final jellyScaleY = 1.0 - (velocityStretch * 0.5);

    // Lateral dock sway for dynamic physical inertia
    final dockSwayX =
        _isDragging ? (_dragVelocityX * 0.0012).clamp(-2.0, 2.0) : 0.0;

    // Calculate transition weight (1.0 = sliding/dragging mirror lens, 0.0 = 3D popping pill)
    final targetNearest = _currentUnitPosition.round();
    final distFromNearest = (_currentUnitPosition - targetNearest).abs();
    final transitionWeight = _isDragging
        ? 1.0
        : (_animController.isAnimating
            ? (distFromNearest * 2.5).clamp(0.0, 1.0)
            : (distFromNearest > 0.02 ? 1.0 : 0.0));

    return Semantics(
      container: true,
      label: l10n.navBarSemanticsLabel,
      child: Padding(
        padding: dockMargin,
        child: Transform.translate(
          offset: Offset(dockSwayX, 0),
          child: Container(
            height: dockHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(dockRadius),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 90 : 20),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 45 : 25),
                  blurRadius: 24,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(dockRadius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(150)
                        : colors.surfaceSecondary.withAlpha(210),
                    borderRadius: BorderRadius.circular(dockRadius),
                    border: Border.all(
                      color: isDark
                          ? colors.white.withAlpha(45)
                          : colors.white.withAlpha(220),
                      width: 1.2,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      final tabCount = _kNavItems.length;
                      final tabWidth = totalWidth / tabCount;
                      final capsuleWidth = tabWidth - (capsuleInsetH * 2);

                      // Calculate sliding capsule left offset
                      final capsuleLeft = capsuleInsetH +
                          (_currentUnitPosition * tabWidth);

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (details) =>
                            _onDragStart(details, totalWidth),
                        onHorizontalDragUpdate: (details) =>
                            _onDragUpdate(details, totalWidth),
                        onHorizontalDragEnd: (details) =>
                            _onDragEnd(details, totalWidth),
                        onHorizontalDragCancel: _onDragCancel,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // -----------------------------------------------
                            // 0. Top Glass Reflection Line (Reflects elements above nav bar)
                            // -----------------------------------------------
                            Positioned(
                              top: 0,
                              left: 20,
                              right: 20,
                              height: 1.8,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.transparent,
                                      colors.white
                                          .withAlpha(isDark ? 100 : 190),
                                      colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // -----------------------------------------------
                            // 1. Base Tab Items Row (Underneath sliding mirror glass lens)
                            // -----------------------------------------------
                            Positioned.fill(
                              child: Row(
                                children: List.generate(tabCount, (index) {
                                  final item = _kNavItems[index];
                                  final label = item.labelBuilder(l10n);

                                  final distance =
                                      (_currentUnitPosition - index).abs();
                                  final activeWeight =
                                      (1.0 - distance).clamp(0.0, 1.0);
                                  final isSelected = activeWeight > 0.5;

                                  return Expanded(
                                    child: Semantics(
                                      button: true,
                                      selected:
                                          widget.tabsRouter.activeIndex == index,
                                      label: l10n.navTabSemantics(
                                        label,
                                        index + 1,
                                        tabCount,
                                      ),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _onTabTapped(index),
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isSelected && transitionWeight <= 0.01
                                                    ? item.activeIcon
                                                    : item.icon,
                                                size: 21,
                                                color: isSelected && transitionWeight <= 0.01
                                                    ? colors.transparent
                                                    : colors.textSecondary,
                                              ),
                                              const SizedBox(height: 3),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  label,
                                                  maxLines: 1,
                                                  style: typography.caption.medium
                                                      .copyWith(
                                                    fontSize: 10.5,
                                                    height: 1.1,
                                                    fontWeight: isSelected && transitionWeight <= 0.01
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: isSelected && transitionWeight <= 0.01
                                                        ? colors.transparent
                                                        : colors.textSecondary,
                                                  ),
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
                            ),

                            // -----------------------------------------------
                            // 2. Translucent Mirror Glass Lens (Transition) vs 3D Popping Pill (Settled)
                            // -----------------------------------------------
                            Positioned(
                              left: capsuleLeft,
                              top: capsuleInsetV,
                              width: capsuleWidth,
                              height: capsuleHeight,
                              child: Transform.scale(
                                scaleX: jellyScaleX,
                                scaleY: jellyScaleY,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(capsuleRadius),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: transitionWeight > 0.01
                                          ? LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: isDark
                                                  ? [
                                                      colors.white.withAlpha(
                                                        (45 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                      colors.white.withAlpha(
                                                        (15 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                    ]
                                                  : [
                                                      colors.white.withAlpha(
                                                        (140 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                      colors.white.withAlpha(
                                                        (70 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                    ],
                                            )
                                          : LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: isDark
                                                  ? [
                                                      colors.primary,
                                                      colors.primary
                                                          .withAlpha(190),
                                                    ]
                                                  : [
                                                      colors.primary,
                                                      colors.primary
                                                          .withAlpha(240),
                                                    ],
                                            ),
                                      borderRadius:
                                          BorderRadius.circular(capsuleRadius),
                                      border: Border.all(
                                        color: transitionWeight > 0.01
                                            ? colors.white.withAlpha(
                                                (210 * transitionWeight).toInt(),
                                              )
                                            : colors.primary.withAlpha(
                                                isDark ? 160 : 120,
                                              ),
                                        width: 1.4,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: transitionWeight > 0.01
                                              ? colors.black.withAlpha(
                                                  isDark ? 50 : 20,
                                                )
                                              : colors.primary.withAlpha(
                                                  isDark ? 120 : 80,
                                                ),
                                          blurRadius: transitionWeight > 0.01
                                              ? 10
                                              : 18,
                                          spreadRadius: transitionWeight > 0.01
                                              ? 0
                                              : 2,
                                          offset: Offset(
                                            0,
                                            transitionWeight > 0.01 ? 2 : 6,
                                          ),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Real-time glass lens backdrop blur during transition
                                        if (transitionWeight > 0.01)
                                          Positioned.fill(
                                            child: BackdropFilter(
                                              filter: ui.ImageFilter.blur(
                                                sigmaX: 8,
                                                sigmaY: 8,
                                              ),
                                              child: Container(
                                                color: colors.transparent,
                                              ),
                                            ),
                                          ),

                                        // Top & bottom liquid glass chromatic refraction arcs during transition (Images 2 & 3)
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: _LiquidLensEdgePainter(
                                              opacity: transitionWeight,
                                              cyan: context.neural.cyan,
                                              fuchsia: context.neural.fuchsia500,
                                              amber: context.neural.amber400,
                                            ),
                                          ),
                                        ),

                                        // 3D Bevel Top Specular Crest when settled (Image 1 3D Pop)
                                        if (transitionWeight <= 0.01)
                                          Positioned(
                                            top: 0,
                                            left: 10,
                                            right: 10,
                                            height: 2.2,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(1),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    colors.transparent,
                                                    colors.white.withAlpha(220),
                                                    colors.transparent,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // -----------------------------------------------
                            // 3. Active 3D Popping Tab Item Overlay (Settled)
                            // -----------------------------------------------
                            if (transitionWeight <= 0.01)
                              Positioned(
                                left: capsuleLeft,
                                top: capsuleInsetV,
                                width: capsuleWidth,
                                height: capsuleHeight,
                                child: IgnorePointer(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _kNavItems[widget.tabsRouter.activeIndex]
                                              .activeIcon,
                                          size: 21,
                                          color: colors.white,
                                        ),
                                        const SizedBox(height: 3),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            _kNavItems[widget.tabsRouter.activeIndex]
                                                .labelBuilder(l10n),
                                            maxLines: 1,
                                            style: typography.caption.bold.copyWith(
                                              fontSize: 10.5,
                                              height: 1.1,
                                              color: colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Chromatic liquid glass edge arc painter for sliding mirror lens transition (Images 2 & 3)
class _LiquidLensEdgePainter extends CustomPainter {
  const _LiquidLensEdgePainter({
    required this.opacity,
    required this.cyan,
    required this.fuchsia,
    required this.amber,
  });

  final double opacity;
  final Color cyan;
  final Color fuchsia;
  final Color amber;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height / 2),
    );

    // Top iridescent liquid glass arc
    final topPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          cyan.withAlpha((210 * opacity).toInt()),
          Colors.white.withAlpha((255 * opacity).toInt()),
          amber.withAlpha((210 * opacity).toInt()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Bottom iridescent liquid glass arc
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          fuchsia.withAlpha((210 * opacity).toInt()),
          cyan.withAlpha((230 * opacity).toInt()),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height - 6, size.width, 6))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    canvas
      ..drawPath(
        Path()..addRRect(rrect),
        topPaint,
      )
      ..drawPath(
        Path()..addRRect(rrect),
        bottomPaint,
      );
  }

  @override
  bool shouldRepaint(covariant _LiquidLensEdgePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
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
