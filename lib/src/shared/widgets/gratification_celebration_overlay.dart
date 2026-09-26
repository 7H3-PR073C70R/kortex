import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Mind-blowing gratification celebration overlay with multi-cannon confetti blast,
/// pulsing glowing aura, floating celebratory badge, animated XP count-up,
/// accomplishment stat pills, and high-engagement re-practice actions.
class GratificationCelebrationOverlay extends StatefulWidget {
  const GratificationCelebrationOverlay({
    required this.title,
    required this.subtitle,
    this.primaryStatLabel,
    this.primaryStatValue,
    this.secondaryStatLabel,
    this.secondaryStatValue,
    this.tertiaryStatLabel,
    this.tertiaryStatValue,
    this.xpEarned,
    this.streakCount,
    this.motivationalBadge,
    this.onDismiss,
    this.buttonText = 'Awesome!',
    this.secondaryButtonText,
    this.onSecondaryAction,
    this.emoji = '🏆',
    super.key,
  });

  final String title;
  final String subtitle;
  final String? primaryStatLabel;
  final String? primaryStatValue;
  final String? secondaryStatLabel;
  final String? secondaryStatValue;
  final String? tertiaryStatLabel;
  final String? tertiaryStatValue;
  final int? xpEarned;
  final int? streakCount;
  final String? motivationalBadge;
  final VoidCallback? onDismiss;
  final String buttonText;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryAction;
  final String emoji;

  /// Shows the gratification celebration modal with full confetti burst and mind-blowing animations.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? primaryStatLabel,
    String? primaryStatValue,
    String? secondaryStatLabel,
    String? secondaryStatValue,
    String? tertiaryStatLabel,
    String? tertiaryStatValue,
    int? xpEarned,
    int? streakCount,
    String? motivationalBadge,
    VoidCallback? onDismiss,
    String buttonText = 'Awesome!',
    String? secondaryButtonText,
    VoidCallback? onSecondaryAction,
    String emoji = '🏆',
  }) {
    unawaited(HapticFeedback.heavyImpact());
    return showDialog<void>(
      context: context,
      builder: (_) => GratificationCelebrationOverlay(
        title: title,
        subtitle: subtitle,
        primaryStatLabel: primaryStatLabel,
        primaryStatValue: primaryStatValue,
        secondaryStatLabel: secondaryStatLabel,
        secondaryStatValue: secondaryStatValue,
        tertiaryStatLabel: tertiaryStatLabel,
        tertiaryStatValue: tertiaryStatValue,
        xpEarned: xpEarned,
        streakCount: streakCount,
        motivationalBadge: motivationalBadge,
        onDismiss: onDismiss,
        buttonText: buttonText,
        secondaryButtonText: secondaryButtonText,
        onSecondaryAction: onSecondaryAction,
        emoji: emoji,
      ),
    );
  }

  @override
  State<GratificationCelebrationOverlay> createState() =>
      _GratificationCelebrationOverlayState();
}

class _GratificationCelebrationOverlayState
    extends State<GratificationCelebrationOverlay>
    with TickerProviderStateMixin {
  late final ConfettiController _topConfetti;
  late final ConfettiController _leftConfetti;
  late final ConfettiController _rightConfetti;

  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _badgeFloatController;

  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _badgeScaleAnimation;

  @override
  void initState() {
    super.initState();

    _topConfetti = ConfettiController(duration: const Duration(seconds: 3));
    _leftConfetti = ConfettiController(duration: const Duration(seconds: 3));
    _rightConfetti = ConfettiController(duration: const Duration(seconds: 3));

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeIn,
    );

    _badgeScaleAnimation = Tween<double>(begin: 0.2, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.8, curve: Curves.elasticOut),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    unawaited(_pulseController.repeat(reverse: true));

    _badgeFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    unawaited(_badgeFloatController.repeat(reverse: true));

    // Blast dual/triple confetti cannons
    _topConfetti.play();
    _leftConfetti.play();
    _rightConfetti.play();
    unawaited(_entranceController.forward());

    // Tactile haptic symphony
    unawaited(
      Future.delayed(const Duration(milliseconds: 220), () {
        unawaited(HapticFeedback.mediumImpact());
      }),
    );
    unawaited(
      Future.delayed(const Duration(milliseconds: 550), () {
        unawaited(HapticFeedback.lightImpact());
      }),
    );
  }

  @override
  void dispose() {
    _topConfetti.dispose();
    _leftConfetti.dispose();
    _rightConfetti.dispose();
    _entranceController.dispose();
    _pulseController.dispose();
    _badgeFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final confettiColors = [
      colors.primary,
      colors.success,
      colors.warning,
      colors.secondary,
      colors.deepBronze,
      colors.quartzCyan,
      const Color(0xFFFFD700), // Gold
      const Color(0xFFFF6584), // Rose
      const Color(0xFF7B2CBF), // Electric purple
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        // Top Shower Confetti
        Positioned(
          top: 0,
          child: ConfettiWidget(
            confettiController: _topConfetti,
            blastDirection: math.pi / 2,
            maxBlastForce: 25,
            minBlastForce: 10,
            emissionFrequency: 0.06,
            numberOfParticles: 35,
            gravity: 0.18,
            colors: confettiColors,
          ),
        ),

        // Left Angle Cannon (shoots up and right across screen)
        Positioned(
          left: 0,
          bottom: 120,
          child: ConfettiWidget(
            confettiController: _leftConfetti,
            blastDirection: -math.pi / 3.5, // ~51 degrees up-right
            maxBlastForce: 35,
            minBlastForce: 15,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.22,
            colors: confettiColors,
          ),
        ),

        // Right Angle Cannon (shoots up and left across screen)
        Positioned(
          right: 0,
          bottom: 120,
          child: ConfettiWidget(
            confettiController: _rightConfetti,
            blastDirection: -math.pi + math.pi / 3.5, // ~129 degrees up-left
            maxBlastForce: 35,
            minBlastForce: 15,
            emissionFrequency: 0.05,
            numberOfParticles: 25,
            gravity: 0.22,
            colors: confettiColors,
          ),
        ),

        // Main Dialog Card
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dialog(
                backgroundColor: colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 22),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 110 : 70),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          blurRadius: 36,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 100 : 30),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.dialog),
                      child: Stack(
                        children: [
                          // Background Ambient Radial Glow
                          Positioned(
                            top: -40,
                            left: 0,
                            right: 0,
                            child: AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, _) {
                                final pulse = _pulseController.value;
                                return Center(
                                  child: Container(
                                    width: 220 + (pulse * 30),
                                    height: 220 + (pulse * 30),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          colors.primary.withAlpha(
                                            (isDark ? 65 : 45) +
                                                (pulse * 25).toInt(),
                                          ),
                                          colors.syllabotAccent.withAlpha(
                                            (isDark ? 40 : 25) +
                                                (pulse * 15).toInt(),
                                          ),
                                          colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Floating Animated Badge with Glowing Aura
                                AnimatedBuilder(
                                  animation: _badgeFloatController,
                                  builder: (context, child) {
                                    final floatY =
                                        math.sin(_badgeFloatController.value *
                                                math.pi) *
                                            4.0;
                                    return Transform.translate(
                                      offset: Offset(0, -floatY),
                                      child: child,
                                    );
                                  },
                                  child: ScaleTransition(
                                    scale: _badgeScaleAnimation,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Outer pulsing halo ring
                                        AnimatedBuilder(
                                          animation: _pulseController,
                                          builder: (context, _) {
                                            final scale =
                                                1.0 + (_pulseController.value * 0.15);
                                            final opacity =
                                                0.6 - (_pulseController.value * 0.3);
                                            return Transform.scale(
                                              scale: scale,
                                              child: Container(
                                                width: 88,
                                                height: 88,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: colors.primary
                                                        .withValues(alpha: opacity),
                                                    width: 2,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),

                                        // Badge Main Orb
                                        Container(
                                          width: 82,
                                          height: 82,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [
                                                colors.primary,
                                                colors.syllabotAccent,
                                                colors.secondary,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: colors.primary.withAlpha(
                                                  isDark ? 130 : 90,
                                                ),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              widget.emoji,
                                              style: typography.body.regular
                                                  .copyWith(fontSize: 40),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Motivational Pill Badge (if available)
                                if (widget.motivationalBadge != null ||
                                    widget.streakCount != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(
                                        isDark ? 45 : 25,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.badge,
                                      ),
                                      border: Border.all(
                                        color: colors.primary.withAlpha(
                                          isDark ? 80 : 50,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      widget.motivationalBadge ??
                                          '🔥 ${widget.streakCount}-Session Streak Active!',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.primary,
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Title
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: typography.title2.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 22,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle
                                Text(
                                  widget.subtitle,
                                  textAlign: TextAlign.center,
                                  style: typography.body.medium.copyWith(
                                    color: colors.textSecondary,
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),

                                // XP Earned Animated Ticker Pill
                                if (widget.xpEarned != null &&
                                    widget.xpEarned! > 0) ...[
                                  const SizedBox(height: 16),
                                  _AnimatedXpPill(
                                    xpEarned: widget.xpEarned!,
                                    colors: colors,
                                    typography: typography,
                                    isDark: isDark,
                                  ),
                                ],

                                // Stats Row
                                if (widget.primaryStatValue != null ||
                                    widget.secondaryStatValue != null ||
                                    widget.tertiaryStatValue != null) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceTertiary,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.panel,
                                      ),
                                      border: Border.all(
                                        color: colors.surfaceBorder.withAlpha(
                                          isDark ? 70 : 40,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        if (widget.primaryStatValue != null)
                                          _StatPill(
                                            label: widget.primaryStatLabel ??
                                                'Score',
                                            value: widget.primaryStatValue!,
                                            color: colors.primary,
                                            colors: colors,
                                            typography: typography,
                                          ),
                                        if (widget.primaryStatValue != null &&
                                            widget.secondaryStatValue != null)
                                          Container(
                                            width: 1,
                                            height: 28,
                                            color: colors.surfaceBorder,
                                          ),
                                        if (widget.secondaryStatValue != null)
                                          _StatPill(
                                            label: widget.secondaryStatLabel ??
                                                'Cards',
                                            value: widget.secondaryStatValue!,
                                            color: colors.recallEasy,
                                            colors: colors,
                                            typography: typography,
                                          ),
                                        if (widget.tertiaryStatValue != null) ...[
                                          Container(
                                            width: 1,
                                            height: 28,
                                            color: colors.surfaceBorder,
                                          ),
                                          _StatPill(
                                            label: widget.tertiaryStatLabel ??
                                                'Pace',
                                            value: widget.tertiaryStatValue!,
                                            color: colors.warning,
                                            colors: colors,
                                            typography: typography,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 24),

                                // Dismiss / Primary CTA Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ShrinkableButton(
                                    onTap: () {
                                      unawaited(HapticFeedback.mediumImpact());
                                      Navigator.of(context).pop();
                                      widget.onDismiss?.call();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            colors.primary,
                                            colors.primary.withAlpha(220),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.panel,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.primary.withAlpha(
                                              isDark ? 80 : 50,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          widget.buttonText,
                                          style: typography.body.bold.copyWith(
                                            color: colors.white,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // Optional Secondary Button (e.g. Review Mistakes, Rematch, Practice More)
                                if (widget.secondaryButtonText != null) ...[
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ShrinkableButton(
                                      onTap: () {
                                        unawaited(HapticFeedback.lightImpact());
                                        Navigator.of(context).pop();
                                        widget.onSecondaryAction?.call();
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.panel,
                                          ),
                                          border: Border.all(
                                            color: colors.surfaceBorder
                                                .withAlpha(120),
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            widget.secondaryButtonText!,
                                            style: typography.body.semiBold
                                                .copyWith(
                                                  color: colors.textPrimary,
                                                  fontSize: 14,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AnimatedXpPill extends StatelessWidget {
  const _AnimatedXpPill({
    required this.xpEarned,
    required this.colors,
    required this.typography,
    required this.isDark,
  });

  final int xpEarned;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colors.warning.withAlpha(isDark ? 45 : 25),
        borderRadius: BorderRadius.circular(
          AppRadius.badge,
        ),
        border: Border.all(
          color: colors.warning.withAlpha(
            isDark ? 100 : 70,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            color: colors.warning,
            size: 20,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: xpEarned.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Text(
                  '+${value.toInt()} Scholar XP Earned',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.bold.copyWith(
                    color: colors.warning,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
    required this.colors,
    required this.typography,
  });

  final String label;
  final String value;
  final Color color;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: typography.caption.bold.copyWith(
            color: colors.textSecondary,
            fontSize: 9.5,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: typography.subhead.bold.copyWith(
            color: color,
            fontSize: 15.5,
          ),
        ),
      ],
    );
  }
}
