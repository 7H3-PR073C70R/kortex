import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
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

/// Interactive spotlight walkthrough overlay that guides users through the core
/// features of Kortex after they enter the workspace.
class AppGuidedTourOverlay extends StatefulWidget {
  const AppGuidedTourOverlay({
    super.key,
    this.onTourCompleted,
  });

  final VoidCallback? onTourCompleted;

  /// Launches the full-screen interactive tour over the root navigator.
  static Future<void> start(
    BuildContext context, {
    VoidCallback? onCompleted,
  }) async {
    final storage = locator<LocalStorageService>();
    unawaited(HapticFeedback.mediumImpact());

    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return FadeTransition(
          opacity: animation,
          child: AppGuidedTourOverlay(
            onTourCompleted: () {
              unawaited(
                storage.savePreference(
                  key: PrefKeys.hasCompletedInteractiveTour,
                  data: 'true',
                ),
              );
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

  // Animation controller for spotlight morphing between steps
  late final AnimationController _morphController;
  late Animation<double> _morphAnimation;
  Rect? _previousTargetRect;
  Rect? _currentTargetRect;

  // Animation controller for pulse aura around highlighted element
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final List<_TourStep> _steps;

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

    _steps = [
      // 1. Dashboard & Academic Header
      _TourStep(
        badge: 'STEP 1 OF 5 • DASHBOARD',
        title: 'Academic Command Center',
        subtitle: 'Daily streak, neural tier & exam countdown',
        description:
            'Monitor your daily study consistency, level up your Neural Scholar tier, and see exact days remaining until your target exams (WAEC, JAMB, or Finals).',
        proTip: 'Tap "Add Exam Countdown" to calibrate an automated cram pace.',
        icon: Icons.speed_rounded,
        accentColor: const Color(0xFF388AF6),
        resolveTarget: (context, screenSize, insets) {
          final rect = AppTourKeys.getTargetRect(AppTourKeys.headerProfileKey);
          if (rect != null) {
            // Expand slightly to also encompass the countdown banner if right below
            return Rect.fromLTWH(
              rect.left,
              rect.top,
              rect.width,
              math.min(rect.height + 64, 150),
            );
          }
          return Rect.fromLTWH(
            16,
            insets.top + 8,
            screenSize.width - 32,
            135,
          );
        },
      ),

      // 2. Daily Active Recall Queue
      _TourStep(
        badge: 'STEP 2 OF 5 • ACTIVE RECALL',
        title: 'Daily Review Queue',
        subtitle: 'Scientifically spaced flashcard reviews',
        description:
            'Never cram at the last minute. Cards due for review appear right here every morning, scheduled by the FSRS algorithm right before you are predicted to forget.',
        proTip: 'Completing 10–15 cards a day cements durable long-term recall.',
        icon: Icons.alarm_on_rounded,
        accentColor: const Color(0xFF10B981),
        resolveTarget: (context, screenSize, insets) {
          final rect = AppTourKeys.getTargetRect(AppTourKeys.reviewQueueKey);
          if (rect != null) return rect;
          return Rect.fromLTWH(
            16,
            insets.top + 160,
            screenSize.width - 32,
            100,
          );
        },
      ),

      // 3. Study Decks & OCR Scanner
      _TourStep(
        badge: 'STEP 3 OF 5 • STUDY DECKS',
        title: 'Smart Decks & Past Papers',
        subtitle: 'Curated decks & AI camera note scanner',
        description:
            'Browse curated past questions and subject curricula, or use the built-in OCR camera scanner to instantly turn textbook pages and lecture slides into active-recall cards.',
        proTip: 'Tap "+" inside Study Decks to convert physical notes into decks.',
        icon: Icons.style_rounded,
        accentColor: const Color(0xFFF59E0B),
        resolveTarget: (context, screenSize, insets) {
          final dockRect = AppTourKeys.getTargetRect(AppTourKeys.dockKey);
          if (dockRect != null) {
            final slotWidth = dockRect.width / 4;
            return Rect.fromLTWH(
              dockRect.left + slotWidth * 1,
              dockRect.top - 4,
              slotWidth,
              dockRect.height + 8,
            );
          }
          final defaultBottom = math.max(16, insets.bottom + 8);
          final slotWidth = (screenSize.width - 32) / 4;
          return Rect.fromLTWH(
            16 + slotWidth * 1,
            screenSize.height - defaultBottom - 64,
            slotWidth,
            64,
          );
        },
      ),

      // 4. Syllabot AI Copilot
      _TourStep(
        badge: 'STEP 4 OF 5 • AI COPILOT',
        title: 'Ask Syllabot 24/7',
        subtitle: 'Your personal Socratic academic tutor',
        description:
            'Stuck on a tricky math equation, physics proof, or past question? Tap this floating copilot anytime on any screen for step-by-step guidance and concept breakdowns.',
        proTip: 'Syllabot floats above all screens so help is always one tap away.',
        icon: Icons.psychology_rounded,
        accentColor: const Color(0xFF8B5CF6),
        resolveTarget: (context, screenSize, insets) {
          final rect = AppTourKeys.getTargetRect(AppTourKeys.syllabotFabKey);
          if (rect != null) return rect;
          final defaultBottom = math.max(84, insets.bottom + 72);
          return Rect.fromLTWH(
            screenSize.width - 160,
            screenSize.height - defaultBottom - 48,
            142,
            48,
          );
        },
      ),

      // 5. Collaborative Study Hub & Live Rooms
      _TourStep(
        badge: 'STEP 5 OF 5 • COMMUNITY',
        title: 'Collaborative Study Hub',
        subtitle: 'Live virtual study rooms & leaderboards',
        description:
            'Connect with fellow candidates and scholars. Join synchronized Pomodoro live study rooms, discuss challenging questions in subject forums, and climb academic rankings.',
        proTip: 'Studying in live virtual rooms boosts focus and accountability.',
        icon: Icons.groups_rounded,
        accentColor: const Color(0xFF06B6D4),
        resolveTarget: (context, screenSize, insets) {
          final dockRect = AppTourKeys.getTargetRect(AppTourKeys.dockKey);
          if (dockRect != null) {
            final slotWidth = dockRect.width / 4;
            return Rect.fromLTWH(
              dockRect.left + slotWidth * 2,
              dockRect.top - 4,
              slotWidth,
              dockRect.height + 8,
            );
          }
          final defaultBottom = math.max(16, insets.bottom + 8);
          final slotWidth = (screenSize.width - 32) / 4;
          return Rect.fromLTWH(
            16 + slotWidth * 2,
            screenSize.height - defaultBottom - 64,
            slotWidth,
            64,
          );
        },
      ),
    ];

    // Initialize targets after first layout frame
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

    // Resolve animated spotlight rectangle
    final fromRect = _previousTargetRect ??
        step.resolveTarget(context, screenSize, insets);
    final toRect = _currentTargetRect ??
        step.resolveTarget(context, screenSize, insets);
    final animatedRect = Rect.lerp(fromRect, toRect, _morphAnimation.value) ??
        toRect;

    // Determine whether the target is in the upper or lower half of screen
    final isTargetInTopHalf = animatedRect.center.dy < screenSize.height * 0.48;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finishTour();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
                    scrimColor: isDark
                        ? const Color(0xE8080C14)
                        : const Color(0xDB111827),
                  ),
                );
              },
            ),

            // 2. Non-blocking tap to dismiss/advance
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
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: step.accentColor.withAlpha(isDark ? 100 : 70),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: step.accentColor.withAlpha(isDark ? 50 : 30),
                          blurRadius: 36,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: colors.black.withAlpha(120),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Top Row: Badge & Skip Button
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
                                  borderRadius: BorderRadius.circular(10),
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
                            TextButton(
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
                                borderRadius: BorderRadius.circular(12),
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

                        // Step Description
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
                            borderRadius: BorderRadius.circular(10),
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

                        // Bottom Navigation Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Step dots
                            Row(
                              children: List.generate(_steps.length, (idx) {
                                final isSelected = idx == _currentStepIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.only(right: 6),
                                  width: isSelected ? 20 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? step.accentColor
                                        : colors.surfaceBorderHighlight,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),

                            // Buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_currentStepIndex > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
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
                                        style: typography.caption.bold.copyWith(
                                          color: colors.textSecondary,
                                          fontSize: 12,
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
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: step.accentColor.withAlpha(80),
                                          blurRadius: 10,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isLastStep
                                              ? 'Start Learning'
                                              : 'Next Step',
                                          style:
                                              typography.caption.bold.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          isLastStep
                                              ? Icons
                                                  .check_circle_outline_rounded
                                              : Icons.arrow_forward_rounded,
                                          color: Colors.white,
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

/// Custom painter that carves a rounded spotlight cutout out of a dark scrim
/// with an animated glowing pulse ring.
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
    // 1. Inflate target slightly for comfortable breathing margin
    final cutoutRect = targetRect.inflate(8);
    final rrect = RRect.fromRectAndRadius(cutoutRect, const Radius.circular(16));

    // 2. Draw scrim with cutout hole
    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(scrimPath, scrimPaint);

    // 3. Draw outer glowing pulse border
    final auraPaint = Paint()
      ..color = accentColor.withAlpha((40 * pulseValue).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * pulseValue
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);

    canvas.drawRRect(rrect, auraPaint);

    // 4. Draw crisp highlight stroke
    final borderPaint = Paint()
      ..color = accentColor.withAlpha((180 * pulseValue).toInt())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.scrimColor != scrimColor;
  }
}
