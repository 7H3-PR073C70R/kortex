import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
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
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1E1B4B),
                    const Color(0xFF312E81),
                    const Color(0xFF1E293B),
                  ]
                : [
                    const Color(0xFFEEF2FF),
                    const Color(0xFFE0E7FF),
                    const Color(0xFFFEF3C7),
                  ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? const Color(0xFF6366F1).withValues(alpha: 0.45)
                : const Color(0xFF6366F1).withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'DAILY ARCADE',
                        style: typography.caption.bold.copyWith(
                          color: Colors.white,
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
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '1 Tap • 5 Min • 12 Rungs',
                    style: typography.caption.medium.copyWith(
                      color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),
                      fontSize: 10.5,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Color(0xFF10B981),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Play Arcade',
                        style: typography.footnote.bold.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
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
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
          size: 14,
        ),
      ),
    );
  }
}
