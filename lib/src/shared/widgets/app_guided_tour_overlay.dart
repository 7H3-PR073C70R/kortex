import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Representation of a granular step in the interactive app walkthrough.
class _TourStep {
  const _TourStep({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.proTip,
    required this.icon,
    required this.accentColor,
    required this.targetTabIndex,
    required this.targetKey,
    this.fallbackKey,
    this.onStepActivated,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String description;
  final String proTip;
  final IconData icon;
  final Color accentColor;
  final int targetTabIndex;
  final GlobalKey targetKey;
  final GlobalKey? fallbackKey;
  final VoidCallback? onStepActivated;

  /// Resolves the spotlight target rectangle accurately based on bound keys
  /// or dynamic responsive screen layout breakpoints.
  Rect resolveTarget(BuildContext context, Size screenSize, EdgeInsets insets) {
    // 1. Primary granular target key check
    final primaryRect = AppTourKeys.getTargetRect(targetKey);
    if (primaryRect != null && primaryRect.width > 0 && primaryRect.height > 0) {
      return primaryRect.inflate(6);
    }

    // 2. Secondary fallback section key check
    if (fallbackKey != null) {
      final fallbackRect = AppTourKeys.getTargetRect(fallbackKey!);
      if (fallbackRect != null && fallbackRect.width > 0 && fallbackRect.height > 0) {
        return fallbackRect.inflate(6);
      }
    }

    // 3. Dynamic Responsive Breakpoint Geometry
    final isDesktop = screenSize.width >= 900;
    final isTablet = screenSize.width >= 600 && screenSize.width < 900;

    final contentWidth = isDesktop
        ? math.min<double>(screenSize.width - 280, 840)
        : isTablet
            ? math.min<double>(screenSize.width - 64, 680)
            : math.min<double>(screenSize.width - 32, 540);

    final left = isDesktop
        ? 240 + (screenSize.width - 240 - contentWidth) / 2
        : (screenSize.width - contentWidth) / 2;

    final top = insets.top + 24;
    return Rect.fromLTWH(left, top, contentWidth, 120);
  }
}

/// Interactive spotlight walkthrough overlay that guides users through ALL core
/// and granular features of Kortex across mobile, tablet, and desktop screens.
class AppGuidedTourOverlay extends StatefulWidget {
  const AppGuidedTourOverlay({
    super.key,
    this.onTourCompleted,
    this.onTabChange,
  });

  final VoidCallback? onTourCompleted;
  final ValueChanged<int>? onTabChange;

  /// Launches the full-screen interactive tour over the root navigator.
  static Future<void> start(
    BuildContext context, {
    VoidCallback? onCompleted,
    bool force = false,
    VoidCallback? onBeforeStart,
  }) async {
    if (locator.isRegistered<LocalStorageService>()) {
      final storage = locator<LocalStorageService>();
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
    } on Object catch (_) {}

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
            onTabChange: (targetTabIndex) {
              if (tabsRouter != null) {
                tabsRouter.setActiveIndex(targetTabIndex);
              }
            },
            onTourCompleted: () {
              if (locator.isRegistered<LocalStorageService>()) {
                unawaited(
                  locator<LocalStorageService>().savePreference(
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

  List<_TourStep> _steps = const [];

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
    _steps = _buildSteps(context.colors);
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

  List<_TourStep> _buildSteps(AppThemeColorsExtension colors) {
    return [
      // 1. Streak & Neural Scholar Tier
      _TourStep(
        badge: 'STEP 1 OF 15 • DASHBOARD HQ',
        title: 'Daily Streak & Neural Scholar Tier',
        subtitle: 'Streak multiplier & rank elevation',
        description:
            'Track your daily revision consistency. Complete reviews every day to watch your Scholar Tier elevate from Bronze to Diamond and unlock double XP multipliers.',
        proTip:
            'A 7+ day streak unlocks automatic rank promotions and exclusive study room badges.',
        icon: Icons.local_fire_department_rounded,
        accentColor: colors.primary,
        targetTabIndex: 0,
        targetKey: AppTourKeys.headerStreakKey,
        fallbackKey: AppTourKeys.headerProfileKey,
      ),

      // 2. Custom Exam Clock & Track Selector
      _TourStep(
        badge: 'STEP 2 OF 15 • EXAM COUNTDOWN',
        title: 'Exam Clock & Target Syllabus Track',
        subtitle: 'WAEC, NECO, JAMB, SAT & Degree targets',
        description:
            'Set your upcoming exam date. Kortex automatically computes your daily target velocity and tunes practice question difficulty to your track.',
        proTip:
            'Tap your exam badge to manage exam dates and auto-prioritize syllabus topics.',
        icon: Icons.timer_rounded,
        accentColor: colors.warning,
        targetTabIndex: 0,
        targetKey: AppTourKeys.countdownBadgeKey,
        fallbackKey: AppTourKeys.countdownKey,
      ),

      // 3. FSRS Active Recall Memory Queue
      _TourStep(
        badge: 'STEP 3 OF 15 • SPACED REPETITION',
        title: 'Daily Memory Review Queue',
        subtitle: 'FSRS memory retention algorithm',
        description:
            'Cards due for review appear here every morning. Our smart FSRS memory engine schedules cards right before you forget them for 95%+ long-term retention.',
        proTip:
            'Clearing 10-15 due cards each morning keeps your review queue manageable.',
        icon: Icons.alarm_on_rounded,
        accentColor: colors.success,
        targetTabIndex: 0,
        targetKey: AppTourKeys.reviewQueueCountKey,
        fallbackKey: AppTourKeys.reviewQueueKey,
      ),

      // 4. AI Camera OCR Scanner
      _TourStep(
        badge: 'STEP 4 OF 15 • AI OCR SCANNER',
        title: 'AI OCR Note Importer',
        subtitle: 'Convert physical notes to flashcards',
        description:
            'Snap textbook pages, handwriting, or PDF notes with your camera. Syllabot AI automatically extracts key concepts and generates interactive Q&A flashcards.',
        proTip:
            'You can upload multiple pages at once — AI handles diagram labels and formulas.',
        icon: Icons.camera_enhance_rounded,
        accentColor: colors.syllabotAccent,
        targetTabIndex: 0,
        targetKey: AppTourKeys.quickActionOcrKey,
        fallbackKey: AppTourKeys.quickActionsKey,
      ),

      // 5. 1v1 Quiz Duels & Past Question Bank
      _TourStep(
        badge: 'STEP 5 OF 15 • QUIZ DUELS',
        title: 'Live 1v1 Duels & Past Questions',
        subtitle: 'Challenge scholars & test past papers',
        description:
            'Practice past questions grouped by topic, or jump into live 1v1 speed duels with fellow scholars studying the same syllabus track.',
        proTip:
            'Winning quiz duels earns instant XP bonuses and climbs the global leaderboard.',
        icon: Icons.sports_esports_rounded,
        accentColor: colors.primary,
        targetTabIndex: 0,
        targetKey: AppTourKeys.quickActionDuelKey,
        fallbackKey: AppTourKeys.quickActionsKey,
      ),

      // 6. Today's Priority Revision Session
      _TourStep(
        badge: 'STEP 6 OF 15 • REVISION HERO',
        title: "Today's Priority Revision Deck",
        subtitle: 'One-tap active recall launcher',
        description:
            'Kortex selects your highest-yield review deck for today. One tap launches active recall mode with immediate AI feedback on incorrect answers.',
        proTip:
            'Tap "Start Revision" first thing in your morning study session for maximum efficiency.',
        icon: Icons.play_circle_fill_rounded,
        accentColor: colors.primary,
        targetTabIndex: 1,
        targetKey: AppTourKeys.decksHeroStartBtnKey,
        fallbackKey: AppTourKeys.decksTodayHeroKey,
      ),

      // 7. Rapid Study Sprints
      _TourStep(
        badge: 'STEP 7 OF 15 • STUDY SPRINTS',
        title: 'Rapid Sprints (Quick 10 & Power 20)',
        subtitle: 'Bite-sized revision for busy schedules',
        description:
            'Short on time? Choose a 10-card Quick Sprint or a 20-card Power Sprint for fast, focused review sessions during breaks or commutes.',
        proTip:
            'Sprints use smart card weighting to focus on your weakest memory tags first.',
        icon: Icons.bolt_rounded,
        accentColor: colors.warning,
        targetTabIndex: 1,
        targetKey: AppTourKeys.decksSprintChip10Key,
        fallbackKey: AppTourKeys.decksSprintChipsKey,
      ),

      // 8. Subject Track Filter Bar
      _TourStep(
        badge: 'STEP 8 OF 15 • DECK FILTERS',
        title: 'Subject & Syllabus Filter Bar',
        subtitle: 'Organize decks by subject & difficulty',
        description:
            'Filter your deck library by subject (Math, Physics, Biology, Chemistry, Literature) or syllabus track for structured exam revision.',
        proTip:
            'Custom tags let you group decks by chapter or upcoming school test dates.',
        icon: Icons.filter_alt_rounded,
        accentColor: colors.latexHighlight,
        targetTabIndex: 1,
        targetKey: AppTourKeys.decksFilterChipKey,
        fallbackKey: AppTourKeys.decksHeaderKey,
      ),

      // 9. Syllabot 24/7 Socratic AI Tutor
      _TourStep(
        badge: 'STEP 9 OF 15 • AI COPILOT',
        title: 'Ask Syllabot 24/7 AI Tutor',
        subtitle: 'Socratic tutor — floating on every screen',
        description:
            'Stuck on a complex equation or past-paper solution? Tap the floating Syllabot pill on any screen for step-by-step explanations and hint prompts.',
        proTip:
            'Syllabot stays accessible on every page so you never have to leave your session for help.',
        icon: Icons.psychology_rounded,
        accentColor: colors.secondary,
        targetTabIndex: 1,
        targetKey: AppTourKeys.syllabotFabKey,
      ),

      // 10. Study Hub & Liquid Tabs
      _TourStep(
        badge: 'STEP 10 OF 15 • STUDY HUB',
        title: 'Study Hub & Liquid Glass Bar',
        subtitle: 'Focus rooms, Study Circles & Marketplace',
        description:
            'Access all deep-work productivity tools in one command center — live co-working rooms, Pomodoro timers, and deck sharing.',
        proTip:
            'Swipe horizontally across the liquid glass bar to switch hub sections smoothly.',
        icon: Icons.device_hub_rounded,
        accentColor: colors.syllabotAccent,
        targetTabIndex: 3,
        targetKey: AppTourKeys.pomodoroCardKey,
        onStepActivated: () => AppTourKeys.onSelectStudyHubSubTab?.call(0),
      ),

      // 11. Synchronized Live Focus Rooms
      _TourStep(
        badge: 'STEP 11 OF 15 • FOCUS ROOMS',
        title: 'Synchronized Live Focus Rooms',
        subtitle: 'Shared Pomodoro & ambient lo-fi audio',
        description:
            'Join virtual study rooms with scholars worldwide. Sync 25-minute Pomodoro cycles, stream ambient study beats, and share focus goals.',
        proTip:
            'Studying in live focus rooms boosts accountability and awards bonus group XP.',
        icon: Icons.groups_rounded,
        accentColor: colors.primary,
        targetTabIndex: 3,
        targetKey: AppTourKeys.liveRoomJoinBtnKey,
        fallbackKey: AppTourKeys.liveRoomsCardKey,
        onStepActivated: () => AppTourKeys.onSelectStudyHubSubTab?.call(0),
      ),

      // 12. Scholar Deck Marketplace
      _TourStep(
        badge: 'STEP 12 OF 15 • MARKETPLACE',
        title: 'Scholar Deck Marketplace',
        subtitle: 'Community decks & past question sets',
        description:
            'Explore high-yield flashcard decks curated by top scholars and verified educators for your exact exam track.',
        proTip:
            'Tap "Clone Deck" to save any community deck instantly into your library.',
        icon: Icons.storefront_rounded,
        accentColor: colors.warning,
        targetTabIndex: 3,
        targetKey: AppTourKeys.marketplaceCloneBtnKey,
        fallbackKey: AppTourKeys.marketplaceCardKey,
        onStepActivated: () => AppTourKeys.onSelectStudyHubSubTab?.call(2),
      ),

      // 13. Scholar Forum Tag Filters
      _TourStep(
        badge: 'STEP 13 OF 15 • FORUM FILTERS',
        title: 'Scholar Forum & Subject Tags',
        subtitle: 'Track-specific Q&A discussions',
        description:
            'Discuss past question solutions with peers. Filter forum threads by subject tag, exam track (WAEC, NECO, JAMB, SAT), or status.',
        proTip:
            'Filter discussions by "Unanswered" to help fellow scholars and earn reputation points.',
        icon: Icons.forum_rounded,
        accentColor: colors.latexHighlight,
        targetTabIndex: 2,
        targetKey: AppTourKeys.communityTagFilterKey,
        fallbackKey: AppTourKeys.communityHeroKey,
      ),

      // 14. Post Question Button
      _TourStep(
        badge: 'STEP 14 OF 15 • ASK COMMUNITY',
        title: 'Post Questions & Share Solutions',
        subtitle: 'Get answers from scholars & educators',
        description:
            'Post tricky questions, attach paper photos, or discuss exam strategies with students preparing for the same syllabus.',
        proTip:
            'Tag your posts accurately so top scholars in your subject get notified.',
        icon: Icons.post_add_rounded,
        accentColor: colors.primary,
        targetTabIndex: 2,
        targetKey: AppTourKeys.communityPostBtnKey,
      ),

      // 15. Analytics, Settings & Profile
      _TourStep(
        badge: 'STEP 15 OF 15 • PROFILE & HEATMAP',
        title: 'Retention Analytics & Settings',
        subtitle: 'Memory heatmaps, theme swatches & security',
        description:
            'Monitor long-term memory retention heatmaps, view XP progress curves, customize your color palette, and configure AI tutor settings.',
        proTip:
            'Review your weekly retention heatmap every Sunday to target weak topics early.',
        icon: Icons.person_rounded,
        accentColor: colors.primary,
        targetTabIndex: 4,
        targetKey: AppTourKeys.profileHeatmapKey,
        fallbackKey: AppTourKeys.profileCardKey,
      ),
    ];
  }

  Future<void> _updateTargetRect({bool initial = false}) async {
    final step = _steps[_currentStepIndex];
    final size = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final fallbackRect = step.resolveTarget(context, size, insets);

    // Ensure target is scrolled into view if in a Scrollable
    final measuredRect = await AppTourKeys.ensureVisibleAndGetRect(
      step.targetKey,
    );
    final newRect = measuredRect ?? fallbackRect;

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
    } on Object catch (_) {}

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
    if (locator.isRegistered<LocalStorageService>()) {
      unawaited(
        locator<LocalStorageService>().savePreference(
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
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final screenSize = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);

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
                  painter: _SpotlightPainter(
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
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: cardMaxWidth,
                    maxHeight: math.max(
                      180,
                      screenSize.height - minTop - maxBottom - 20,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfacePrimary.withAlpha(245)
                          : colors.surfacePrimary.withAlpha(252),
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: step.accentColor.withAlpha(isDark ? 100 : 70),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 80 : 25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badge & Skip
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: step.accentColor.withAlpha(30),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.badge,
                                    ),
                                    border: Border.all(
                                      color: step.accentColor.withAlpha(90),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: step.accentColor,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          step.badge,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.caption.bold.copyWith(
                                            color: step.accentColor,
                                            fontSize: 10.5,
                                            letterSpacing: 1.1,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              PlatformHoverBuilder(
                                builder: (context, isHovered, child) {
                                  return AnimatedScale(
                                    scale: isHovered ? 1.05 : 1.0,
                                    duration: AppMotion.snappy,
                                    curve: AppMotion.easeOutCubic,
                                    child: child,
                                  );
                                },
                                child: TextButton(
                                  onPressed: _finishTour,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: Text(
                                    'Skip Tour',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Title and Icon Row
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: step.accentColor.withAlpha(35),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.card,
                                  ),
                                  border: Border.all(
                                    color: step.accentColor.withAlpha(80),
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  step.icon,
                                  color: step.accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      step.title,
                                      style: typography.headline.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 16.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      step.subtitle,
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 11.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Description
                          Text(
                            step.description,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              height: 1.4,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Pro-Tip Box
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: step.accentColor.withAlpha(16),
                              borderRadius: BorderRadius.circular(AppRadius.card),
                              border: Border.all(
                                color: step.accentColor.withAlpha(50),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 15,
                                  color: step.accentColor,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    step.proTip,
                                    style: typography.caption.medium.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Navigation Controls
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Step dots
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(_steps.length, (idx) {
                                      final isSelected = idx == _currentStepIndex;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        margin: const EdgeInsets.only(right: 3),
                                        width: isSelected ? 12 : 4,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? step.accentColor
                                              : colors.surfaceBorderHighlight,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.micro,
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Back + Next/Finish buttons
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_currentStepIndex > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: PlatformHoverBuilder(
                                        builder: (context, isHovered, child) {
                                          return AnimatedScale(
                                            scale: isHovered ? 1.05 : 1.0,
                                            duration: AppMotion.snappy,
                                            curve: AppMotion.easeOutCubic,
                                            child: child,
                                          );
                                        },
                                        child: TextButton(
                                          onPressed: _goToPreviousStep,
                                          style: TextButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Back',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: colors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ShrinkableButton(
                                    onTap: _goToNextStep,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: step.accentColor,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.card,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            isLastStep
                                                ? 'Start Learning'
                                                : 'Next Step',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: colors.white,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            isLastStep
                                                ? Icons
                                                      .check_circle_outline_rounded
                                                : Icons.arrow_forward_rounded,
                                            color: colors.white,
                                            size: 15,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter that carves a rounded spotlight cutout out of a dark scrim.
class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter({
    required this.targetRect,
    required this.pulseValue,
    required this.accentColor,
    required this.scrimColor,
  });

  final Rect targetRect;
  final double pulseValue;
  final Color accentColor;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = targetRect.inflate(8);
    final rrect = RRect.fromRectAndRadius(
      cutoutRect,
      const Radius.circular(AppRadius.card),
    );

    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas
      ..drawPath(scrimPath, Paint()..color = scrimColor)
      ..drawRRect(
        rrect,
        Paint()
          ..color = accentColor.withAlpha((180 * pulseValue).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.scrimColor != scrimColor;
  }
}
