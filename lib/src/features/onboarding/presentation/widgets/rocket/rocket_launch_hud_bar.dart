import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Futuristic HUD and Telemetry Bar for the rocket launch overlay.
class RocketLaunchHudBar extends StatelessWidget {
  const RocketLaunchHudBar({
    required this.machSpeed,
    required this.score,
    required this.isWarping,
    required this.onSkip,
    super.key,
  });

  final double machSpeed;
  final int score;
  final bool isWarping;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return SafeArea(
      child: AnimatedOpacity(
        duration: AppMotion.snappy,
        opacity: isWarping ? 0.0 : 1.0,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Mach Speed & Orbit Telemetry
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary.withAlpha(200),
                          borderRadius: AppRadius.radiusPanel,
                          border: Border.all(
                            color: colors.primary.withAlpha(90),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              size: 18,
                              color: colors.syllabotAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isWarping
                                  ? l10n.warpDriveEngaged
                                  : l10n.launchMachSpeed(
                                      machSpeed.toStringAsFixed(1),
                                    ),
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Score / Synapse Mastery Counter
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceSecondary.withAlpha(200),
                          borderRadius: AppRadius.radiusPanel,
                          border: Border.all(
                            color: colors.warning.withAlpha(90),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 18,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$score XP',
                              style: typography.caption.bold.copyWith(
                                color: colors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Skip Button
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: onSkip,
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.surfaceSecondary.withAlpha(220)
                                    : colors.surfaceSecondary.withAlpha(150),
                                borderRadius: AppRadius.radiusPanel,
                                border: Border.all(
                                  color: isHovered
                                      ? colors.surfaceBorderHighlight
                                      : colors.transparent,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Skip',
                                style: typography.caption.medium.copyWith(
                                  color: isHovered
                                      ? colors.textPrimary
                                      : colors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Interactive Steering & Tap Hint
                  if (!isWarping)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(35),
                        borderRadius: AppRadius.radiusDialog,
                        border: Border.all(
                          color: colors.primary.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        l10n.launchSteerHint,
                        style: typography.caption.medium.copyWith(
                          color: colors.syllabotAccent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
