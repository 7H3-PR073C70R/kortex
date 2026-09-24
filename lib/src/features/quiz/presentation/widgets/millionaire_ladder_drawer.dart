import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal bottom sheet visualizing the 12-tier Millionaire prize ascent ladder.
class MillionaireLadderDrawer extends StatelessWidget {
  const MillionaireLadderDrawer({
    required this.state,
    required this.onClose,
    super.key,
  });

  final QuizSessionState state;
  final VoidCallback onClose;

  static void show(BuildContext context, QuizSessionState state) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: context.colors.transparent,
        builder: (modalContext) => MillionaireLadderDrawer(
          state: state,
          onClose: () => Navigator.of(modalContext).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final reduceMotion = quizReduceMotion(context);

    final tiersReversed = List.generate(
      QuizSessionState.millionaireTiersXp.length,
      (i) => QuizSessionState.millionaireTiersXp.length - i,
    );

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
            border: Border.all(
              color: colors.surfaceBorder,
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.surfaceBorder,
                    borderRadius: BorderRadius.circular(AppRadius.micro),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.military_tech_rounded,
                        color: colors.warning,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your prize ladder',
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          Text(
                            'Tiers 4 and 8 are safe: what you bank there '
                            'stays yours.',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Overview summary chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Prize at this tier',
                        value: '${state.currentTierPrizeXp} XP',
                        color: colors.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Already banked',
                        value: '${state.bankedTierPrizeXp} XP',
                        color: colors.success,
                      ),
                    ),
                    if (state.speedBonusXp > 0) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryCard(
                          title: 'Speed bonus',
                          value: '+${state.speedBonusXp} XP',
                          color: colors.syllabotAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 24),

              // Ladder Rungs List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  itemCount: tiersReversed.length,
                  itemBuilder: (context, index) {
                    final tier = tiersReversed[index];
                    final xp = QuizSessionState.millionaireTiersXp[tier - 1];
                    final isCurrent = tier == state.currentTier;
                    final isPassed = tier < state.currentTier;
                    final isSafe = QuizSessionState.safeCheckpointTiers
                        .contains(tier);

                    // Each rung settles in one after another, and the rung
                    // you are on glows once so the eye lands on it.
                    final row = Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? colors.warning.withValues(alpha: 0.18)
                            : (isSafe
                                  ? colors.success.withValues(alpha: 0.08)
                                  : (isDark
                                        ? colors.surfaceSecondary
                                        : colors.cardBackground)),
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(
                          color: isCurrent
                              ? colors.warning
                              : (isSafe
                                    ? colors.success.withValues(alpha: 0.4)
                                    : colors.surfaceBorder.withValues(
                                        alpha: 0.5,
                                      )),
                          width: isCurrent ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Tier Number & Icon
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? colors.warning
                                  : (isPassed
                                        ? colors.success
                                        : colors.surfaceSecondary),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$tier',
                              style: typography.caption.bold.copyWith(
                                color: (isCurrent || isPassed)
                                    ? colors.white
                                    : colors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Safe badge indicator
                          if (isSafe) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppRadius.micro,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shield_rounded,
                                    color: colors.success,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'SAFE',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.success,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],

                          Text(
                            tier == 12 ? 'Top prize' : 'Tier $tier',
                            style: typography.body.medium.copyWith(
                              color: isCurrent
                                  ? colors.warning
                                  : (isPassed
                                        ? colors.textPrimary
                                        : colors.textSecondary),
                            ),
                          ),
                          if (isPassed) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: colors.success,
                            ),
                          ],

                          const Spacer(),

                          // Prize Amount
                          Text(
                            '$xp XP',
                            style: typography.callout.bold.copyWith(
                              color: isCurrent
                                  ? colors.warning
                                  : (isSafe
                                        ? colors.success
                                        : (isPassed
                                              ? colors.textPrimary
                                              : colors.textMuted)),
                            ),
                          ),
                        ],
                      ),
                    );

                    return QuizStaggeredFade(
                      index: index % 8,
                      distance: 8,
                      reduceMotion: reduceMotion,
                      child: isCurrent
                          ? _PulseGlow(
                              color: colors.warning,
                              reduceMotion: reduceMotion,
                              child: row,
                            )
                          : row,
                    );
                  },
                ),
              ),

              // Bottom Resume Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: ShrinkableButton(
                  onTap: onClose,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.warning, colors.warning.withAlpha(200)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.panel),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.15,
                          ),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Keep climbing',
                      style: typography.headline.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single soft glow that swells and settles once, never looping.
/// It marks "you are here" without creating a permanent distraction.
class _PulseGlow extends StatelessWidget {
  const _PulseGlow({
    required this.color,
    required this.reduceMotion,
    required this.child,
  });

  final Color color;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, t, inner) => Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusCard,
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(
                (math.sin(t * math.pi) * 110).round().clamp(0, 110),
              ),
              blurRadius: 20,
              spreadRadius: 1,
            ),
          ],
        ),
        child: inner,
      ),
      child: child,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: typography.callout.bold.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
