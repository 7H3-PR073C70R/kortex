import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Gratifying celebration overlay with rich confetti blast, haptic burst,
/// glowing trophy badge, and session accomplishment breakdown.
class GratificationCelebrationOverlay extends StatefulWidget {
  const GratificationCelebrationOverlay({
    required this.title,
    required this.subtitle,
    this.primaryStatLabel,
    this.primaryStatValue,
    this.secondaryStatLabel,
    this.secondaryStatValue,
    this.xpEarned,
    this.onDismiss,
    this.buttonText = 'Awesome!',
    this.emoji = '🏆',
    super.key,
  });

  final String title;
  final String subtitle;
  final String? primaryStatLabel;
  final String? primaryStatValue;
  final String? secondaryStatLabel;
  final String? secondaryStatValue;
  final int? xpEarned;
  final VoidCallback? onDismiss;
  final String buttonText;
  final String emoji;

  /// Shows the gratification celebration modal with full confetti burst.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? primaryStatLabel,
    String? primaryStatValue,
    String? secondaryStatLabel,
    String? secondaryStatValue,
    int? xpEarned,
    VoidCallback? onDismiss,
    String buttonText = 'Awesome!',
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
        xpEarned: xpEarned,
        onDismiss: onDismiss,
        buttonText: buttonText,
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
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _confettiController.play();
    unawaited(_animController.forward());

    // Haptic feedback sequence
    unawaited(
      Future.delayed(const Duration(milliseconds: 200), () {
        unawaited(HapticFeedback.mediumImpact());
      }),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Confetti Blast
        Positioned(
          top: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirection: math.pi / 2,
            maxBlastForce: 25,
            minBlastForce: 10,
            emissionFrequency: 0.05,
            numberOfParticles: 35,
            gravity: 0.15,
            colors: const [
              Color(0xFF6366F1),
              Color(0xFF10B981),
              Color(0xFFF59E0B),
              Color(0xFFEC4899),
              Color(0xFF8B5CF6),
              Color(0xFF3B82F6),
            ],
          ),
        ),

        // Main Dialog Card
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfacePrimary,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 100 : 60),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 70 : 30),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Floating Animated Badge
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.syllabotAccent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(100),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.emoji,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Title
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: typography.title2.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: typography.body.medium.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                      ),

                      // XP Earned Pill
                      if (widget.xpEarned != null && widget.xpEarned! > 0) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colors.warning.withAlpha(isDark ? 40 : 25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colors.warning.withAlpha(isDark ? 90 : 60),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: Colors.amber,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '+${widget.xpEarned} Scholar XP Earned',
                                style: typography.caption.bold.copyWith(
                                  color: colors.warning,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Stats Row
                      if (widget.primaryStatValue != null ||
                          widget.secondaryStatValue != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.surfaceBorder.withAlpha(
                                isDark ? 60 : 40,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (widget.primaryStatValue != null)
                                _StatPill(
                                  label: widget.primaryStatLabel ?? 'Score',
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
                                  label: widget.secondaryStatLabel ?? 'Cards',
                                  value: widget.secondaryStatValue!,
                                  color: colors.recallEasy,
                                  colors: colors,
                                  typography: typography,
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 22),

                      // Dismiss CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.mediumImpact());
                            Navigator.of(context).pop();
                            widget.onDismiss?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.primary,
                                  colors.primary.withAlpha(220),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withAlpha(isDark ? 70 : 40),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                widget.buttonText,
                                style: typography.body.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 14.5,
                                ),
                              ),
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
      ],
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
        const SizedBox(height: 2),
        Text(
          value,
          style: typography.subhead.bold.copyWith(
            color: color,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
