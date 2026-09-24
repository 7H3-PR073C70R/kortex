import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/di/locator.dart';
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
    required this.resolveTarget,
  });

  final String badge;
  final String title;
  final String subtitle;
  final String description;
  final String proTip;
  final IconData icon;
  final Color accentColor;
  final Rect Function(BuildContext context, Size screenSize, EdgeInsets insets)
  resolveTarget;
}

/// Interactive spotlight walkthrough overlay that guides users through ALL core
/// features of Kortex. Call [AppGuidedTourOverlay.start] — it handles
/// navigation to Dashboard automatically before launching the overlay.
class AppGuidedTourOverlay extends StatefulWidget {
  const AppGuidedTourOverlay({
    super.key,
    this.onTourCompleted,
  });

  final VoidCallback? onTourCompleted;

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

    // Small delay to allow navigation animation to settle.
    if (onBeforeStart != null) {
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }

    if (!context.mounted) return;

    unawaited(HapticFeedback.mediumImpact());

    await showGeneralDialog<void>(
      context: context,
      barrierColor: context.colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: AppGuidedTourOverlay(
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
        badge: 'STEP 1 OF 9 • DASHBOARD',
        title: 'Academic Command Center',
        subtitle: 'Streak, Neural Tier & exam countdown',
        description:
            'This is your daily academic HQ. Track your study streak, watch your Neural Scholar tier rise (Bronze → Platinum → Diamond), and see a live countdown to every exam — WAEC, JAMB, A-levels, or custom finals.',
        proTip:
            'Keeping your streak alive for 7+ days unlocks bonus XP multipliers and league promotions.',
        icon: Icons.speed_rounded,
        accentColor: colors.primary,
        resolveTarget: (context, screenSize, insets) {
          final top = insets.top + 16;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 140);
        },
      ),

      // 2. FSRS Daily Review Queue
      _TourStep(
        badge: 'STEP 2 OF 9 • ACTIVE RECALL',
        title: 'FSRS Daily Review Queue',
        subtitle: 'Science-backed spaced repetition',
        description:
            'Cards due for review appear here every morning, scheduled by the FSRS-6 spaced-repetition algorithm — the same system used by top medical students worldwide. It predicts exactly when you are about to forget and reschedules before that happens.',
        proTip:
            'Just 10-15 reviews per day maintains 95%+ retention permanently. Do not skip your queue.',
        icon: Icons.alarm_on_rounded,
        accentColor: colors.success,
        resolveTarget: (context, screenSize, insets) {
          final top = insets.top + 170;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 120);
        },
      ),

      // 3. Exam Countdown Timer & Cram Planner
      _TourStep(
        badge: 'STEP 3 OF 9 • EXAM PLANNER',
        title: 'Exam Countdown & Cram Planner',
        subtitle: 'Auto-calculated daily study targets',
        description:
            'Add any upcoming exam — WAEC, NECO, JAMB, SAT, or a custom paper — and Kortex generates a day-by-day cram plan. As the countdown hits zero, the timer switches to a full in-app exam clock so you practise under real time pressure.',
        proTip:
            'Tap "Add Exam" on the countdown banner. The algorithm auto-distributes your weaker topics to the days you have most time.',
        icon: Icons.timer_outlined,
        accentColor: colors.warning,
        resolveTarget: (context, screenSize, insets) {
          final top = insets.top + 300;
          final width = math.min<double>(screenSize.width - 32, 560);
          final left = (screenSize.width - width) / 2;
          return Rect.fromLTWH(left, top, width, 80);
        },
      ),

      // 4. Smart Flashcard Decks + OCR
      _TourStep(
        badge: 'STEP 4 OF 9 • FLASHCARD DECKS',
        title: 'Smart Decks & OCR Scanner',
        subtitle: 'AI-curated cards + camera note importer',
        description:
            'Browse thousands of pre-built past-question decks for your syllabus, or use the built-in OCR camera to instantly photograph textbook pages and lecture notes — Kortex converts them to interactive flashcards in seconds.',
        proTip:
            'Use the "+" icon in Decks to scan physical notes. AI auto-generates both sides of each card from your image.',
        icon: Icons.style_rounded,
        accentColor: colors.warning,
        resolveTarget: (context, screenSize, insets) {
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

      // 5. Syllabot AI Copilot
      _TourStep(
        badge: 'STEP 5 OF 9 • AI COPILOT',
        title: 'Ask Syllabot 24/7',
        subtitle: 'Socratic AI tutor — always one tap away',
        description:
            'Stuck on a tricky equation, past question, or concept? Tap the floating Syllabot button anywhere in the app for step-by-step explanations, essay outlines, diagram breakdowns, or even full past-paper marking.',
        proTip:
            'Syllabot stays visible on every screen so you never have to leave your revision session to get help.',
        icon: Icons.psychology_rounded,
        accentColor: colors.secondary,
        resolveTarget: (context, screenSize, insets) {
          final defaultBottom = math.max(84, insets.bottom + 72);
          return Rect.fromLTWH(
            screenSize.width - 160,
            screenSize.height - defaultBottom - 48,
            142,
            48,
          );
        },
      ),

      // 6. Quiz & Mock Exam Engine
      _TourStep(
        badge: 'STEP 6 OF 9 • QUIZ & MOCK EXAM',
        title: 'Quiz Arena & Mock Exam',
        subtitle: 'Timed tests, AI marking & instant review',
        description:
            'Take full timed mock exams or targeted topic quizzes. When finished, the AI marker shows your score, breaks down every wrong answer, compares your response to the correct one, and tells you exactly which topic to revise next.',
        proTip:
            'Use Study Hub to launch a mock exam. Enable "Exam Mode" for a silent, distraction-free timed environment that simulates real exam conditions.',
        icon: Icons.quiz_rounded,
        accentColor: colors.error,
        resolveTarget: (context, screenSize, insets) {
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          // Study Hub tab (index 3 in 5-tab dock)
          return Rect.fromLTWH(
            dockLeft + slotWidth * 3,
            screenSize.height - defaultBottom - 68,
            slotWidth,
            64,
          );
        },
      ),

      // 7. Study Hub & Pomodoro
      _TourStep(
        badge: 'STEP 7 OF 9 • STUDY HUB',
        title: 'Study Hub & Pomodoro Rooms',
        subtitle: 'Focused deep-work sessions with timer',
        description:
            'Access all active learning tools — Pomodoro timer, subject quiz launchers, past-question banks, and curated course materials. The built-in session timer helps you work in focused 25-minute sprints with structured breaks.',
        proTip:
            'Start a Pomodoro session in Study Hub to enter deep-work flow. Sessions track focused-study hours toward your weekly XP milestones.',
        icon: Icons.device_hub_rounded,
        accentColor: colors.syllabotAccent,
        resolveTarget: (context, screenSize, insets) {
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

      // 8. Community Hub & Leaderboard
      _TourStep(
        badge: 'STEP 8 OF 9 • COMMUNITY',
        title: 'Study Community & Leaderboard',
        subtitle: 'Live rooms, forums & academic rankings',
        description:
            'Join synchronized live virtual study rooms with other scholars, discuss challenging past questions in subject forums, share flashcard decks on the marketplace, and compete on the real-time leaderboard to rise through Bronze to Diamond leagues.',
        proTip:
            'Studying in a live virtual room with peers boosts accountability. Rooms use a shared Pomodoro clock so everyone stays in sync.',
        icon: Icons.groups_rounded,
        accentColor: colors.latexHighlight,
        resolveTarget: (context, screenSize, insets) {
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          // Community tab (index 2)
          return Rect.fromLTWH(
            dockLeft + slotWidth * 2,
            screenSize.height - defaultBottom - 68,
            slotWidth,
            64,
          );
        },
      ),

      // 9. Profile, Analytics & Settings
      _TourStep(
        badge: 'STEP 9 OF 9 • PROFILE',
        title: 'Progress Analytics & Profile',
        subtitle: 'Retention heatmap, XP trends & settings',
        description:
            'Your Profile tab shows a retention heatmap, long-term XP curves, subject mastery breakdown, and streak history. Customise your theme accent, notification schedule, and Syllabot AI behaviour all from Appearance & Sounds in your profile.',
        proTip:
            'Check your weekly retention heatmap every Sunday to identify the topics with weakest recall — those are your Monday priorities.',
        icon: Icons.person_rounded,
        accentColor: colors.primary,
        resolveTarget: (context, screenSize, insets) {
          final defaultBottom = math.max(16, insets.bottom + 8);
          final dockWidth = math.min(screenSize.width - 32, 480);
          final dockLeft = (screenSize.width - dockWidth) / 2;
          final slotWidth = dockWidth / 5;
          // Profile tab (index 4)
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

  void _goToNextStep() {
    unawaited(HapticFeedback.lightImpact());
    if (_currentStepIndex < _steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
      _updateTargetRect();
    } else {
      _finishTour();
    }
  }

  void _goToPreviousStep() {
    unawaited(HapticFeedback.lightImpact());
    if (_currentStepIndex > 0) {
      setState(() {
        _currentStepIndex--;
      });
      _updateTargetRect();
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
