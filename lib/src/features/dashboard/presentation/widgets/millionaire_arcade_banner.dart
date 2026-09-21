import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// ADHD-friendly 1-tap entry banner into the randomized Daily Dopamine Arcade (Millionaire Mode).
/// Bypasses backlog decision fatigue with a 5–10 minute cross-subject gamified sprint.
class MillionaireArcadeBanner extends StatelessWidget {
  const MillionaireArcadeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.mediumImpact());
            unawaited(
              context.router.push(
                QuizWorkspaceRoute(
                  deckId: 'arcade_global',
                  deckTitle: 'Daily Dopamine Arcade',
                  assessmentMode: AssessmentMode.millionaireMode,
                ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        colors.surfaceSecondary,
                        colors.surfaceTertiary,
                        colors.surfacePrimary,
                      ]
                    : [
                        colors.surfacePrimary,
                        colors.backgroundSecondary,
                        colors.surfaceTertiary,
                      ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isHovered
                    ? colors.primary.withValues(alpha: isDark ? 0.7 : 0.5)
                    : colors.primary.withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top badges
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.warning, colors.slateTerracotta],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.military_tech_rounded,
                        color: colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DAILY ARCADE',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (isDark ? colors.white : colors.black).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Text(
                    '1 Tap • 5 Min • 12 Rungs',
                    style: typography.caption.medium.copyWith(
                      color: isDark ? colors.latexHighlight : colors.primary,
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colors.success.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    color: colors.success,
                    size: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Main Title & Subtitle
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Climb the Millionaire Ascent',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bypass decision fatigue with a quick cross-subject sprint. Bank checkpoints at Tiers 4 & 8 to protect your XP!',
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Footer / Action row
            Row(
              children: [
                // Lifelines preview
                Row(
                  children: [
                    _MiniIconBadge(
                      icon: Icons.filter_2_rounded,
                      tooltip: '50:50 Lifeline',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _MiniIconBadge(
                      icon: Icons.auto_awesome_rounded,
                      tooltip: 'AI Clue',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),
                    _MiniIconBadge(
                      icon: Icons.groups_rounded,
                      tooltip: 'Ask the Crowd',
                      isDark: isDark,
                    ),
                  ],
                ),
                const Spacer(),

                // CTA Button
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.syllabotAccent],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Play Arcade',
                        style: typography.footnote.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: colors.white,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
        },
      );
  }
}

class _MiniIconBadge extends StatelessWidget {
  const _MiniIconBadge({
    required this.icon,
    required this.tooltip,
    required this.isDark,
  });

  final IconData icon;
  final String tooltip;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: (isDark ? colors.white : colors.black).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.badge),
        ),
        child: Icon(
          icon,
          color: isDark ? colors.latexHighlight : colors.primary,
          size: 14,
        ),
      ),
    );
  }
}
