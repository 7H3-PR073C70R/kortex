import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/guided_tour/spotlight_painter.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_guide_card.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_step_model.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_steps_data.dart';

export 'package:kortex/src/shared/widgets/guided_tour/tour_step_model.dart';

/// Interactive spotlight walkthrough overlay that guides users through ALL core
/// and granular features of Kortex across mobile, tablet, and desktop screens.
class AppGuidedTourOverlay extends StatefulWidget {
  const AppGuidedTourOverlay({
    super.key,
    this.onTourCompleted,
    this.onTabChange,
    this.localStorageService,
    this.steps,
  });

  final VoidCallback? onTourCompleted;
  final ValueChanged<int>? onTabChange;
  final LocalStorageService? localStorageService;
  final List<TourStep>? steps;

  /// Launches the full-screen interactive tour over the root navigator.
  static Future<void> start(
    BuildContext context, {
    VoidCallback? onCompleted,
    bool force = false,
    VoidCallback? onBeforeStart,
    LocalStorageService? localStorageService,
  }) async {
    final storage = localStorageService ??
        (locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null);

    if (storage != null) {
      final hasCompleted =
          storage.getPreference(key: PrefKeys.hasCompletedInteractiveTour) ==
          'true';

      if (!force && hasCompleted) {
        return;
      }
    }

    // Switch to Dashboard tab first so spotlights land on the right widgets.
    onBeforeStart?.call();

    TabsRouter? tabsRouter;
    try {
      tabsRouter = AutoTabsRouter.of(context);
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }

    if (onBeforeStart != null) {
      await Future<void>.delayed(const Duration(milliseconds: 380));
    }

    if (!context.mounted) return;

    unawaited(HapticFeedback.mediumImpact());

    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: AppGuidedTourOverlay(
            localStorageService: storage,
            onTabChange: (targetTabIndex) {
              if (tabsRouter != null) {
                tabsRouter.setActiveIndex(targetTabIndex);
              }
            },
            onTourCompleted: () {
              if (storage != null) {
                unawaited(
                  storage.savePreference(
                    key: PrefKeys.hasCompletedInteractiveTour,
                    data: 'true',
                  ),
                );
              }
              onCompleted?.call();
            },
          ),
        );
      },
    );
  }

  @override
  State<AppGuidedTourOverlay> createState() => _AppGuidedTourOverlayState();
}

class _AppGuidedTourOverlayState extends State<AppGuidedTourOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentStepIndex = 0;

  late final AnimationController _morphController;
  late Animation<double> _morphAnimation;
  Rect? _previousTargetRect;
  Rect? _currentTargetRect;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  List<TourStep> _steps = const [];

  LocalStorageService? get _storage =>
      widget.localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _morphAnimation = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    unawaited(_pulseController.repeat(reverse: true));
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_updateTargetRect(initial: true));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _steps = widget.steps ?? buildTourSteps(context.colors);
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // React to window resizes and orientation changes dynamically
    if (mounted) {
      unawaited(_updateTargetRect());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _morphController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _updateTargetRect({bool initial = false}) async {
    if (_steps.isEmpty) return;
    final step = _steps[_currentStepIndex];
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final fallbackRect = step.resolveTarget(context, size, insets);

    // Ensure target is scrolled into view if in a Scrollable
    var measuredRect = await AppTourKeys.ensureVisibleAndGetRect(
      step.targetKey,
    );
    if ((measuredRect == null || measuredRect.width <= 0) &&
        step.fallbackKey != null) {
      measuredRect = await AppTourKeys.ensureVisibleAndGetRect(
        step.fallbackKey!,
      );
    }

    final newRect =
        (measuredRect != null && measuredRect.width > 0 && measuredRect.height > 0)
            ? measuredRect.inflate(6)
            : fallbackRect;

    if (!mounted) return;

    setState(() {
      _previousTargetRect = initial ? newRect : (_currentTargetRect ?? newRect);
      _currentTargetRect = newRect;
    });

    if (!initial) {
      unawaited(_morphController.forward(from: 0));
    } else {
      _morphController.value = 1;
    }
  }

  void _onStepChange(int newIndex) {
    setState(() {
      _currentStepIndex = newIndex;
    });

    final step = _steps[newIndex];
    final targetTabIndex = step.targetTabIndex;

    // Switch tab dynamically via parent widget callback & AutoTabsRouter
    widget.onTabChange?.call(targetTabIndex);

    try {
      final tabsRouter = AutoTabsRouter.of(context);
      if (tabsRouter.activeIndex != targetTabIndex) {
        tabsRouter.setActiveIndex(targetTabIndex);
      }
    } on Object catch (e, st) {
      AppLogger.recordNonFatal(e, st);
    }

    // Trigger sub-tab activation callback (e.g. Study Hub inner tabs)
    step.onStepActivated?.call();

    _scheduleTargetRemeasurement();
  }

  void _scheduleTargetRemeasurement() {
    unawaited(_updateTargetRect());

    final delays = [60, 180, 350, 520];
    for (final delay in delays) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted) {
          unawaited(_updateTargetRect());
        }
      });
    }
  }

  void _goToNextStep() {
    unawaited(HapticFeedback.lightImpact());
    if (_currentStepIndex < _steps.length - 1) {
      _onStepChange(_currentStepIndex + 1);
    } else {
      _finishTour();
    }
  }

  void _goToPreviousStep() {
    unawaited(HapticFeedback.lightImpact());
    if (_currentStepIndex > 0) {
      _onStepChange(_currentStepIndex - 1);
    }
  }

  void _finishTour() {
    unawaited(HapticFeedback.mediumImpact());
    final storage = _storage;
    if (storage != null) {
      unawaited(
        storage.savePreference(
          key: PrefKeys.hasCompletedInteractiveTour,
          data: 'true',
        ),
      );
    }
    widget.onTourCompleted?.call();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final screenSize = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);

    if (_steps.isEmpty) return const SizedBox.shrink();

    final step = _steps[_currentStepIndex];
    final isLastStep = _currentStepIndex == _steps.length - 1;

    final fromRect =
        _previousTargetRect ?? step.resolveTarget(context, screenSize, insets);
    final toRect =
        _currentTargetRect ?? step.resolveTarget(context, screenSize, insets);
    final animatedRect =
        Rect.lerp(fromRect, toRect, _morphAnimation.value) ?? toRect;

    final minTop = insets.top + 16;
    final maxBottom = math.max<double>(76, insets.bottom + 68);

    final spaceAbove = animatedRect.top - minTop - 16;
    final spaceBelow = (screenSize.height - maxBottom) - animatedRect.bottom - 16;

    final placeBelow = spaceBelow >= 210 || spaceBelow >= spaceAbove;

    double? cardTop;
    double? cardBottom;

    if (placeBelow) {
      cardTop = math.min(
        math.max(animatedRect.bottom + 16, minTop),
        screenSize.height - maxBottom - 260,
      );
    } else {
      cardBottom = math.min(
        math.max(screenSize.height - animatedRect.top + 16, maxBottom),
        screenSize.height - minTop - 260,
      );
    }

    final cardMaxWidth = math.min<double>(screenSize.width - 32, 440);
    final cardMaxHeight = math.max<double>(
      180,
      screenSize.height - minTop - maxBottom - 20,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishTour();
      },
      child: Scaffold(
        backgroundColor: colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Custom Spotlight Scrim & Glowing Cutout
            AnimatedBuilder(
              animation: Listenable.merge([_morphAnimation, _pulseAnimation]),
              builder: (context, _) {
                return CustomPaint(
                  size: screenSize,
                  painter: SpotlightPainter(
                    targetRect: animatedRect,
                    pulseValue: _pulseAnimation.value,
                    accentColor: step.accentColor,
                    scrimColor: colors.black.withAlpha(isDark ? 232 : 219),
                  ),
                );
              },
            ),

            // 2. Non-blocking tap to advance
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _goToNextStep,
                child: const SizedBox.expand(),
              ),
            ),

            // 3. Interactive Floating Guide Card
            Positioned(
              left: 16,
              right: 16,
              top: cardTop,
              bottom: cardBottom,
              child: Center(
                child: TourGuideCard(
                  step: step,
                  currentStepIndex: _currentStepIndex,
                  totalSteps: _steps.length,
                  isLastStep: isLastStep,
                  cardMaxWidth: cardMaxWidth,
                  cardMaxHeight: cardMaxHeight,
                  onFinishTour: _finishTour,
                  onNextStep: _goToNextStep,
                  onPreviousStep: _goToPreviousStep,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
