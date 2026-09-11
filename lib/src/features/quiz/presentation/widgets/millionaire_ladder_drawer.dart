import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
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
        backgroundColor: Colors.transparent,
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

    final tiersReversed = List.generate(
      QuizSessionState.millionaireTiersXp.length,
      (i) => QuizSessionState.millionaireTiersXp.length - i,
    );

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.5),
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
                borderRadius: BorderRadius.circular(10),
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
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Millionaire Prize Ladder',
                        style: typography.title3.bold,
                      ),
                      Text(
                        'Guaranteed Safe Checkpoints at Tier 4 & 8',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
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
                    title: 'Current Tier Prize',
                    value: '${state.currentTierPrizeXp} XP',
                    color: const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryCard(
                    title: 'Banked Safety Net',
                    value: '${state.bankedTierPrizeXp} XP',
                    color: const Color(0xFF10B981),
                  ),
                ),
                if (state.speedBonusXp > 0) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Speed Bonus',
                      value: '+${state.speedBonusXp} XP',
                      color: const Color(0xFF6366F1),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              itemCount: tiersReversed.length,
              itemBuilder: (context, index) {
                final tier = tiersReversed[index];
                final xp = QuizSessionState.millionaireTiersXp[tier - 1];
                final isCurrent = tier == state.currentTier;
                final isPassed = tier < state.currentTier;
                final isSafe = QuizSessionState.safeCheckpointTiers.contains(tier);

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.18)
                        : (isSafe
                            ? const Color(0xFF10B981).withValues(alpha: 0.08)
                            : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02))),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent
                          ? const Color(0xFFF59E0B)
                          : (isSafe
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Colors.transparent),
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
                              ? const Color(0xFFF59E0B)
                              : (isPassed
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.white12 : Colors.black12)),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$tier',
                          style: typography.caption.bold.copyWith(
                            color: (isCurrent || isPassed)
                                ? Colors.white
                                : colors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Safe badge indicator
                      if (isSafe) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.shield_rounded,
                                color: Color(0xFF10B981),
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'SAFE',
                                style: typography.caption.bold.copyWith(
                                  color: const Color(0xFF10B981),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],

                      Text(
                        tier == 12 ? '🏆 GRAND PRIZE' : 'Tier $tier',
                        style: typography.body.medium.copyWith(
                          color: isCurrent
                              ? const Color(0xFFF59E0B)
                              : (isPassed ? colors.textPrimary : colors.textSecondary),
                        ),
                      ),

                      const Spacer(),

                      // Prize Amount
                      Text(
                        '$xp XP',
                        style: typography.callout.bold.copyWith(
                          color: isCurrent
                              ? const Color(0xFFF59E0B)
                              : (isSafe
                                  ? const Color(0xFF10B981)
                                  : (isPassed
                                      ? colors.textPrimary
                                      : colors.textMuted)),
                        ),
                      ),
                    ],
                  ),
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
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Continue Ascent',
                  style: typography.headline.bold.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
        borderRadius: BorderRadius.circular(12),
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
