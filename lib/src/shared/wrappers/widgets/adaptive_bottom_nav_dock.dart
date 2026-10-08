import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/wrappers/widgets/main_nav_item.dart';
import 'package:kortex/src/shared/wrappers/widgets/nav_tab_handler.dart';

/// World-Leading Floating Liquid Glass Navigation Dock (< 1024dp)
/// Authentic Apple Draggable Liquid Glass Physics, Concentric Stadium Capsule,
/// Real-time Velocity Jelly Deformation, Specular Refraction, and Ambient Glow
class AdaptiveBottomNavDock extends StatefulWidget {
  const AdaptiveBottomNavDock({
    required this.tabsRouter,
    super.key,
  });

  final TabsRouter tabsRouter;

  @override
  State<AdaptiveBottomNavDock> createState() => _AdaptiveBottomNavDockState();
}

class _AdaptiveBottomNavDockState extends State<AdaptiveBottomNavDock>
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
    _currentUnitPosition = 0.0;
    _lastHapticIndex = 0;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    widget.tabsRouter.addListener(_onTabsRouterChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    final initialDockIndex = AppTabNavigation.mainIndexToDockIndex(
      widget.tabsRouter.activeIndex,
      width,
    );
    _currentUnitPosition = initialDockIndex.toDouble();
    _lastHapticIndex = initialDockIndex;
  }

  void _onTabsRouterChanged() {
    if (!mounted) return;
    final width = MediaQuery.sizeOf(context).width;
    final dockIndex = AppTabNavigation.mainIndexToDockIndex(
      widget.tabsRouter.activeIndex,
      width,
    );
    if (dockIndex != _lastHapticIndex && !_isDragging) {
      _lastHapticIndex = dockIndex;
      _animateToTab(dockIndex);
    }
  }

  @override
  void didUpdateWidget(covariant AdaptiveBottomNavDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tabsRouter != widget.tabsRouter) {
      oldWidget.tabsRouter.removeListener(_onTabsRouterChanged);
      widget.tabsRouter.addListener(_onTabsRouterChanged);
    }
    if (mounted) {
      final width = MediaQuery.sizeOf(context).width;
      final dockIndex = AppTabNavigation.mainIndexToDockIndex(
        widget.tabsRouter.activeIndex,
        width,
      );
      if (dockIndex != _lastHapticIndex && !_isDragging) {
        _lastHapticIndex = dockIndex;
        _animateToTab(dockIndex);
      }
    }
  }

  @override
  void dispose() {
    widget.tabsRouter.removeListener(_onTabsRouterChanged);
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
    const tabCount = 4;
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
    const tabCount = 4;
    // Fling velocity adjustment for flick gestures
    final velocityUnit = (details.primaryVelocity ?? 0.0) / 700.0;
    final targetDockIndex =
        (_currentUnitPosition + velocityUnit * 0.35).round().clamp(0, tabCount - 1);

    setState(() {
      _isDragging = false;
      _dragVelocityX = 0;
      _lastHapticIndex = targetDockIndex;
    });

    _animateToTab(targetDockIndex);

    final width = MediaQuery.sizeOf(context).width;
    final mainIndex = AppTabNavigation.dockIndexToMainIndex(targetDockIndex, width);
    final l10n = context.l10n;
    final label = kNavItems4[targetDockIndex].labelBuilder(l10n);
    handleTabTap(context, widget.tabsRouter, mainIndex, label);
  }

  void _onDragCancel() {
    setState(() {
      _isDragging = false;
      _dragVelocityX = 0.0;
    });
    final width = MediaQuery.sizeOf(context).width;
    final dockIndex = AppTabNavigation.mainIndexToDockIndex(
      widget.tabsRouter.activeIndex,
      width,
    );
    _animateToTab(dockIndex);
  }

  void _onTabTapped(int dockIndex) {
    final width = MediaQuery.sizeOf(context).width;
    final mainIndex = AppTabNavigation.dockIndexToMainIndex(dockIndex, width);
    final l10n = context.l10n;
    final label = kNavItems4[dockIndex].labelBuilder(l10n);

    if (widget.tabsRouter.activeIndex == mainIndex) {
      handleTabTap(context, widget.tabsRouter, mainIndex, label);
      return;
    }

    _lastHapticIndex = dockIndex;
    _animateToTab(dockIndex);
    handleTabTap(context, widget.tabsRouter, mainIndex, label);
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
    const capsuleHeight = dockHeight - (capsuleInsetV * 2); // 54dp

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
          child: SizedBox(
            height: dockHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // -----------------------------------------------
                // 0. Base Neutral 3D Liquid Glass Dock Track
                // -----------------------------------------------
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(dockRadius),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 85 : 20),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(dockRadius),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? colors.black.withAlpha(35)
                                : colors.white.withAlpha(125),
                            borderRadius: BorderRadius.circular(dockRadius),
                            border: Border.all(
                              color: isDark
                                  ? colors.white.withAlpha(40)
                                  : colors.white.withAlpha(180),
                            ),
                          ),
                          child: Stack(
                            children: [
                              // Pure Neutral 3D Specular Top Glass Crest Line
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
                                        colors.white.withAlpha(isDark ? 120 : 200),
                                        colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom Glass Rim Inset Shadow for 3D Volume
                              Positioned(
                                bottom: 0,
                                left: 20,
                                right: 20,
                                height: 1.2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        colors.transparent,
                                        colors.black.withAlpha(isDark ? 50 : 20),
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
                ),

                // -----------------------------------------------
                // 1. Dock Content (Tab Row + WhatsApp 1-1 Overflowing Lens)
                // -----------------------------------------------
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalWidth = constraints.maxWidth;
                      const tabCount = 4;
                      final tabWidth = totalWidth / tabCount;

                      // Dynamic Lerp Geometry for WhatsApp 1-1 Transition Expansion
                      final currentInsetV =
                          ui.lerpDouble(6.0, -5.0, transitionWeight)!;
                      final currentHeight =
                          ui.lerpDouble(54.0, 76.0, transitionWeight)!;
                      final currentRadius =
                          ui.lerpDouble(27.0, 38.0, transitionWeight)!;

                      // Expand width horizontally in transition
                      final settledCapsuleWidth = tabWidth - 8.0;
                      final transitionCapsuleWidth = tabWidth + 22.0;
                      final capsuleWidth = ui.lerpDouble(
                        settledCapsuleWidth,
                        transitionCapsuleWidth,
                        transitionWeight,
                      )!;
                      final capsuleLeft = 4.0 +
                          (_currentUnitPosition * tabWidth) -
                          ((capsuleWidth - settledCapsuleWidth) / 2);

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
                            // Top Dock Specular Reflection Line
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
                            // Base Tab Items Row (High Transparency Visibility Under Lens)
                            // -----------------------------------------------
                            Positioned.fill(
                              child: Row(
                                children: List.generate(tabCount, (dockIndex) {
                                  final item = kNavItems4[dockIndex];
                                  final label = item.labelBuilder(l10n);

                                  final distance =
                                      (_currentUnitPosition - dockIndex).abs();
                                  final activeWeight =
                                      (1.0 - distance).clamp(0.0, 1.0);
                                  final isSelected = activeWeight > 0.5;

                                  final isRouteSelected =
                                      AppTabNavigation.mainIndexToDockIndex(
                                            widget.tabsRouter.activeIndex,
                                            totalWidth,
                                          ) ==
                                          dockIndex;

                                  final iconColor = isSelected && transitionWeight <= 0.01
                                      ? colors.transparent
                                      : (isSelected ? colors.textPrimary : colors.textSecondary);
                                  final textColor = isSelected && transitionWeight <= 0.01
                                      ? colors.transparent
                                      : (isSelected ? colors.textPrimary : colors.textSecondary);

                                  return Expanded(
                                    child: Semantics(
                                      button: true,
                                      selected: isRouteSelected,
                                      label: l10n.navTabSemantics(
                                        label,
                                        dockIndex + 1,
                                        tabCount,
                                      ),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _onTabTapped(dockIndex),
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
                                                color: iconColor,
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
                                                    fontWeight: isSelected
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                    color: textColor,
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
                            // Translucent Glass Lens (Transition) vs 3D Popping Pill (Settled)
                            // -----------------------------------------------
                            Positioned(
                              left: capsuleLeft,
                              top: currentInsetV,
                              width: capsuleWidth,
                              height: currentHeight,
                              child: Transform.scale(
                                scaleX: jellyScaleX,
                                scaleY: jellyScaleY,
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(currentRadius),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: transitionWeight > 0.01
                                          ? LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: isDark
                                                  ? [
                                                      colors.white.withAlpha(
                                                        (22 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                      colors.white.withAlpha(
                                                        (8 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                    ]
                                                  : [
                                                      colors.white.withAlpha(
                                                        (45 * transitionWeight)
                                                            .toInt(),
                                                      ),
                                                      colors.white.withAlpha(
                                                        (18 * transitionWeight)
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
                                          BorderRadius.circular(currentRadius),
                                      border: Border.all(
                                        color: transitionWeight > 0.01
                                            ? colors.white.withAlpha(
                                                (220 * transitionWeight).toInt(),
                                              )
                                            : colors.primary.withAlpha(
                                                isDark ? 160 : 120,
                                              ),
                                        width: transitionWeight > 0.01 ? 1.5 : 1.4,
                                      ),
                                      boxShadow: transitionWeight > 0.01
                                          ? const []
                                          : [
                                              BoxShadow(
                                                color: colors.primary.withAlpha(
                                                  isDark ? 120 : 80,
                                                ),
                                                blurRadius: 18,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Chromatic Liquid Edge Refraction Arcs during transition
                                        Positioned.fill(
                                          child: CustomPaint(
                                            painter: LiquidLensEdgePainter(
                                              opacity: transitionWeight,
                                              cyan: context.neural.cyan,
                                              fuchsia: context.neural.fuchsia500,
                                              amber: context.neural.amber400,
                                            ),
                                          ),
                                        ),

                                        // 3D Bevel Top Specular Crest when settled
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
                            // Active 3D Popping Tab Item Overlay (Settled)
                            // -----------------------------------------------
                            if (transitionWeight <= 0.01)
                              Positioned(
                                left: capsuleLeft,
                                top: currentInsetV,
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
                                          kNavItems4[_currentUnitPosition.round().clamp(0, kNavItems4.length - 1)]
                                              .activeIcon,
                                          size: 21,
                                          color: colors.white,
                                        ),
                                        const SizedBox(height: 3),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            kNavItems4[_currentUnitPosition.round().clamp(0, kNavItems4.length - 1)]
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Chromatic liquid glass edge arc painter for sliding mirror lens transition
class LiquidLensEdgePainter extends CustomPainter {
  const LiquidLensEdgePainter({
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
  bool shouldRepaint(covariant LiquidLensEdgePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}
