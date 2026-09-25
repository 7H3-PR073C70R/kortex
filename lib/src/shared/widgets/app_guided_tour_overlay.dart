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

/// Representation of a single step in the interactive app walkthrough.
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
    required this.resolveTarget,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String description;
  final String proTip;
  final IconData icon;
  final Color accentColor;
  final int targetTabIndex;
  final Rect Function(BuildContext context, Size screenSize, EdgeInsets insets)
  resolveTarget;
}

/// Interactive spotlight walkthrough overlay that guides users through ALL core
/// features of Kortex. Call [AppGuidedTourOverlay.start] — it handles
/// navigation across tabs automatically during the walkthrough.
class AppGuidedTourOverlay extends StatefulWidget {
  const AppGuidedTourOverlay({
    super.key,
    this.onTourCompleted,
    this.onTabChange,
  });

  final VoidCallback? onTourCompleted;
  final ValueChanged<int>? onTabChange;

  /// Launches the full-screen interactive tour over the root navigator.
  ///
  /// If [force] is false (default), the tour only shows if the user has
  /// never completed or skipped it before.
  ///
  /// Pass [onBeforeStart] to navigate to Dashboard before the overlay mounts
  /// (e.g. from About page or profile menu).
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

    // Resolve outer TabsRouter before mounting root dialog!
    TabsRouter? tabsRouter;
    try {
      tabsRouter = AutoTabsRouter.of(context);
    } on Object catch (_) {}

    // Small delay to allow navigation animation to settle.
    if (onBeforeStart != null) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
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
    with TickerProviderStateMixin {
  int _currentStepIndex = 0;

  late final AnimationController _morphController;
  late Animation<double> _morphAnimation;
  Rect? _previousTargetRect;
  Rect? _currentTargetRect;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  List<_TourStep> _steps = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _steps = _buildSteps(context.colors);
  }

  List<_TourStep> _buildSteps(AppThemeColorsExtension colors) {
    return [
      // 1. Academic Command Center
      _TourStep(
        badge: 'STEP 1 OF 14 • DASHBOARD',
        title: 'Academic HQ & Neural Tier',
        subtitle: 'Streak counter, level progress & scholar identity',
        description:
            'Welcome to Kortexify! Track your daily study streak, watch your Neural Scholar tier elevate from Bronze to Diamond, and monitor your XP multipliers.',
        proTip:
            'Maintaining a 7+ day streak unlocks double XP multipliers and automatic league promotion.',
        icon: Icons.speed_rounded,
        accentColor: colors.primary,
        targetTabIndex: 0,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.headerProfileKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 16;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 140);
        },
      ),

      // 2. FSRS Spaced-Repetition Queue
      _TourStep(
        badge: 'STEP 2 OF 14 • ACTIVE RECALL',
        title: 'FSRS-6 Daily Review Queue',
        subtitle: 'Science-backed spaced repetition engine',
        description:
            'Cards due for review appear here every morning, scheduled by the FSRS-6 algorithm. It predicts exact memory decay curves so you review right before forgetting.',
        proTip:
            'Just 10-15 reviews per day maintains 95%+ retention permanently. Do not skip your queue.',
        icon: Icons.alarm_on_rounded,
        accentColor: colors.success,
        targetTabIndex: 0,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.reviewQueueKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 170;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 120);
        },
      ),

      // 3. Exam Countdown & Cram Planner
      _TourStep(
        badge: 'STEP 3 OF 14 • EXAM PLANNER',
        title: 'Exam Countdown & Cram Clock',
        subtitle: 'Auto-calculated daily study velocity',
        description:
            'Add upcoming exams like WAEC, NECO, JAMB, SAT, or university finals. Kortex automatically builds a daily study target and switches to a timed exam clock on test day.',
        proTip:
            'Tap "Add Exam" on the countdown banner to let the algorithm balance your weaker topics.',
        icon: Icons.timer_outlined,
        accentColor: colors.warning,
        targetTabIndex: 0,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.countdownKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 300;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 80);
        },
      ),

      // 4. AI Quick Actions Suite
      _TourStep(
        badge: 'STEP 4 OF 14 • AI TOOLS',
        title: 'AI Study Tools & Quick Launcher',
        subtitle: 'OCR note upload, Q-Bank & 1v1 Quiz Duels',
        description:
            'Instant entry point for active learning: snap notes with the AI OCR camera, launch subject past-question banks, or challenge scholars to live 1v1 quiz duels.',
        proTip:
            'Use "Upload Notes" to convert physical textbook photos into structured flashcards in seconds.',
        icon: Icons.auto_awesome_rounded,
        accentColor: colors.syllabotAccent,
        targetTabIndex: 0,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.quickActionsKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 400;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 100);
        },
      ),

      // 5. Smart Flashcard Decks & Note Importer
      _TourStep(
        badge: 'STEP 5 OF 14 • FLASHCARD DECKS',
        title: 'Smart Decks & Note Importer',
        subtitle: 'Syllabus-curated decks & camera scanner',
        description:
            'Browse thousands of pre-built past-question decks for your syllabus, or use the camera importer to instantly generate interactive flashcards from your notes.',
        proTip:
            'Decks are automatically tagged by subject and difficulty weights for structured revision.',
        icon: Icons.style_rounded,
        accentColor: colors.warning,
        targetTabIndex: 1,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.decksHeaderKey);
          if (measured != null) return measured.inflate(6);
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          return Rect.fromLTWH(
            dockLeft + slotWidth,
            screenSize.height - defaultBottom - 68,
            slotWidth,
            64,
          );
        },
      ),

      // 6. Today's Revision Hero Session
      _TourStep(
        badge: 'STEP 6 OF 14 • REVISION HERO',
        title: 'Today\'s Priority Revision Session',
        subtitle: 'Single-click active recall launcher',
        description:
            'Kortex identifies your highest-priority review deck for today. One tap launches active recall mode with real-time AI feedback on incorrect answers.',
        proTip:
            'Complete your hero revision card first thing every morning for peak memory retention.',
        icon: Icons.play_circle_fill_rounded,
        accentColor: colors.primary,
        targetTabIndex: 1,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.decksTodayHeroKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 180;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 140);
        },
      ),

      // 7. Rapid Study Sprints & Focus Mode
      _TourStep(
        badge: 'STEP 7 OF 14 • STUDY SPRINTS',
        title: 'Rapid Sprints & Hyperdrive Focus',
        subtitle: '10-card, 20-card & speed-run revision modes',
        description:
            'Short on time? Launch Quick 10 or Power 20 sprints. Or activate Hyperdrive Focus Mode for a silent, distraction-free study sprint.',
        proTip:
            'Quick 10 sprints are ideal for quick study sessions during commute or break times.',
        icon: Icons.bolt_rounded,
        accentColor: colors.warning,
        targetTabIndex: 1,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.decksSprintChipsKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 340;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 60);
        },
      ),

      // 8. Ask Syllabot 24/7 AI Tutor
      _TourStep(
        badge: 'STEP 8 OF 14 • AI COPILOT',
        title: 'Ask Syllabot 24/7 AI Tutor',
        subtitle: 'Socratic AI tutor — always one tap away',
        description:
            'Stuck on a tricky equation, past paper question, or concept? Tap the floating Syllabot button on any screen for step-by-step explanations, essay outlines, or past-paper marking.',
        proTip:
            'Syllabot stays visible on every screen so you never have to leave your revision session for help.',
        icon: Icons.psychology_rounded,
        accentColor: colors.secondary,
        targetTabIndex: 1,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.syllabotFabKey);
          if (measured != null) return measured.inflate(8);
          final defaultBottom = math.max(84, insets.bottom + 72);
          return Rect.fromLTWH(
            screenSize.width - 160,
            screenSize.height - defaultBottom - 48,
            142,
            48,
          );
        },
      ),

      // 9. Study Hub Command Center
      _TourStep(
        badge: 'STEP 9 OF 14 • STUDY HUB',
        title: 'Study Hub Command Center',
        subtitle: 'Live focus rooms, Study Circles & Marketplace',
        description:
            'Access all deep-work tools using the Liquid Glass tab bar — co-working focus rooms, subject study circles, and community deck marketplace.',
        proTip:
            'Swipe horizontally across the Liquid Glass tab bar to switch rooms instantly.',
        icon: Icons.device_hub_rounded,
        accentColor: colors.syllabotAccent,
        targetTabIndex: 3,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.pomodoroCardKey);
          if (measured != null) return measured.inflate(6);
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          return Rect.fromLTWH(
            dockLeft + slotWidth * 3,
            screenSize.height - defaultBottom - 68,
            slotWidth,
            64,
          );
        },
      ),

      // 10. Synchronized Live Focus Rooms
      _TourStep(
        badge: 'STEP 10 OF 14 • FOCUS ROOMS',
        title: 'Synchronized Live Focus Rooms',
        subtitle: 'Shared Pomodoro timers & ambient audio',
        description:
            'Join virtual study rooms with scholars worldwide. Features synchronized 25-minute Pomodoro clocks, lo-fi beats, ambient audio, and shared study goals.',
        proTip:
            'Co-working in live focus rooms boosts study accountability and earns bonus group XP.',
        icon: Icons.groups_rounded,
        accentColor: colors.primary,
        targetTabIndex: 3,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.liveRoomsCardKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 140;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 180);
        },
      ),

      // 11. Scholar Deck Marketplace
      _TourStep(
        badge: 'STEP 11 OF 14 • MARKETPLACE',
        title: 'Scholar Deck Marketplace',
        subtitle: 'Community-curated decks & past questions',
        description:
            'Browse and clone high-yield flashcard decks curated by top scholars and verified educators for your exact exam track.',
        proTip:
            'Clone any marketplace deck with one tap to save it directly to your personal library.',
        icon: Icons.storefront_rounded,
        accentColor: colors.warning,
        targetTabIndex: 3,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.marketplaceCardKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 140;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 180);
        },
      ),

      // 12. Scholar Community & Forum
      _TourStep(
        badge: 'STEP 12 OF 14 • COMMUNITY',
        title: 'Scholar Community & Forum',
        subtitle: 'Track-specific Q&A forums & discussions',
        description:
            'Discuss challenging past questions, share solutions with peers, and filter discussions by your academic track (WAEC, JAMB, A-Levels, SAT).',
        proTip:
            'Filter forum discussions by "Trending" or "Unanswered" to help fellow scholars.',
        icon: Icons.forum_rounded,
        accentColor: colors.latexHighlight,
        targetTabIndex: 2,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.communityHeroKey);
          if (measured != null) return measured.inflate(6);
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          return Rect.fromLTWH(
            dockLeft + slotWidth * 2,
            screenSize.height - defaultBottom - 68,
            slotWidth,
            64,
          );
        },
      ),

      // 13. Post Questions & Discuss Solutions
      _TourStep(
        badge: 'STEP 13 OF 14 • CREATE DISCUSSION',
        title: 'Post Questions & Discuss Solutions',
        subtitle: 'Ask the scholar community for help',
        description:
            'Post questions, attach images of past paper equations, or start academic debates with scholars studying the same syllabus.',
        proTip:
            'Add subject tags when posting so scholars in your track get instant notifications.',
        icon: Icons.post_add_rounded,
        accentColor: colors.primary,
        targetTabIndex: 2,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.communityPostBtnKey);
          if (measured != null) return measured.inflate(6);
          final top = insets.top + 16;
          return Rect.fromLTWH(screenSize.width - 100, top, 80, 40);
        },
      ),

      // 14. Analytics, Settings & Customization
      _TourStep(
        badge: 'STEP 14 OF 14 • PROFILE',
        title: 'Analytics, Settings & Customization',
        subtitle: 'Retention heatmaps, theme swatches & security',
        description:
            'Track long-term retention heatmaps and XP curves. Customize your theme palette, Socratic AI behavior, biometric lock, and account security.',
        proTip:
            'Check your weekly retention heatmap every Sunday to target weak topics for the upcoming week.',
        icon: Icons.person_rounded,
        accentColor: colors.primary,
        targetTabIndex: 4,
        resolveTarget: (context, screenSize, insets) {
          final measured = AppTourKeys.getTargetRect(AppTourKeys.profileCardKey);
          if (measured != null) return measured.inflate(6);
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          return Rect.fromLTWH(
            dockLeft + slotWidth * 4,
            screenSize.height - defaultBottom - 68,
            slotWidth,
            64,
          );
        },
      ),
    ];
  }

  @override
  void initState() {
    super.initState();

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
        _updateTargetRect(initial: true);
      }
    });
  }

  @override
  void dispose() {
    _morphController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _updateTargetRect({bool initial = false}) {
    final screenSize = MediaQuery.sizeOf(context);
    final insets = MediaQuery.paddingOf(context);
    final step = _steps[_currentStepIndex];
    final newRect = step.resolveTarget(context, screenSize, insets);

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

    final targetTabIndex = _steps[newIndex].targetTabIndex;

    // Switch tab dynamically via parent widget callback & AutoTabsRouter
    widget.onTabChange?.call(targetTabIndex);

    try {
      final tabsRouter = AutoTabsRouter.of(context);
      if (tabsRouter.activeIndex != targetTabIndex) {
        tabsRouter.setActiveIndex(targetTabIndex);
      }
    } on Object catch (_) {}

    // Allow frame rendering & tab switch animation before re-measuring target rect
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _updateTargetRect();
      }
    });
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

    final isTargetInTopHalf = animatedRect.center.dy < screenSize.height * 0.48;

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
              left: 20,
              right: 20,
              top: isTargetInTopHalf
                  ? math.max(animatedRect.bottom + 24, insets.top + 160)
                  : null,
              bottom: !isTargetInTopHalf
                  ? math.max(
                      screenSize.height - animatedRect.top + 20,
                      insets.bottom + 84,
                    )
                  : null,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
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
                        const SizedBox(height: 12),

                        // Title and Icon Row
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
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
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    step.title,
                                    style: typography.headline.bold.copyWith(
                                      color: colors.textPrimary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step.subtitle,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          step.description,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.45,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pro-Tip Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
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
                                size: 16,
                                color: step.accentColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  step.proTip,
                                  style: typography.caption.medium.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Navigation Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Step dots
                            Row(
                              children: List.generate(_steps.length, (idx) {
                                final isSelected = idx == _currentStepIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.only(right: 5),
                                  width: isSelected ? 18 : 5,
                                  height: 5,
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
