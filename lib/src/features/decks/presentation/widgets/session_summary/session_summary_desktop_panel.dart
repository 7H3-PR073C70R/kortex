import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Desktop layout for SessionSummaryPage presenting a dimmed blur backdrop
/// and a right slide-over panel container.
class SessionSummaryDesktopPanel extends StatelessWidget {
  const SessionSummaryDesktopPanel({
    required this.celebrate,
    required this.reduceMotion,
    required this.confettiController,
    required this.onClose,
    required this.child,
    super.key,
  });

  final bool celebrate;
  final bool reduceMotion;
  final ConfettiController confettiController;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Stack(
      children: [
        // Dimmed Backdrop Overlay with opaque hit testing
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color: Colors.black.withValues(
                    alpha: isDark ? 0.50 : 0.30,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Confetti overlay on celebration
        if (celebrate && !reduceMotion)
          Positioned(
            top: 0,
            right: 280,
            child: ConfettiWidget(
              confettiController: confettiController,
              blastDirection: math.pi / 2,
              maxBlastForce: 25,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              numberOfParticles: 35,
              gravity: 0.15,
              colors: [
                colors.primary,
                colors.success,
                colors.warning,
                colors.secondary,
                colors.deepBronze,
                colors.quartzCyan,
              ],
            ),
          ),

        // Right Slide-in Compact Panel (Width 560px)
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          width: 560,
          child: Material(
            elevation: 16,
            color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
            shape: Border(
              left: BorderSide(
                color: colors.primary.withAlpha(isDark ? 80 : 50),
                width: 1.5,
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Panel Header
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        PlatformHoverBuilder(
                          builder: (context, isHovered, _) {
                            return IconButton(
                              icon: AnimatedContainer(
                                duration: AppMotion.snappy,
                                curve: AppMotion.easeOutCubic,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isHovered
                                      ? (isDark
                                            ? colors.surfaceSecondary
                                            : colors.surfacePrimary)
                                      : (isDark
                                            ? colors.surfaceSecondary.withAlpha(180)
                                            : colors.surfacePrimary.withAlpha(200)),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isHovered
                                        ? colors.primary.withAlpha(120)
                                        : colors.surfaceBorder.withAlpha(80),
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: isHovered ? colors.primary : colors.textPrimary,
                                  size: 18,
                                ),
                              ),
                              onPressed: onClose,
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Session Summary',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: colors.surfaceBorder.withAlpha(isDark ? 50 : 80),
                  ),

                  // Panel Body Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate()
              .slideX(
                begin: 1,
                end: 0,
                duration: 320.ms,
                curve: Curves.easeOutCubic,
              )
              .fadeIn(duration: 200.ms),
        ),
      ],
    );
  }
}
