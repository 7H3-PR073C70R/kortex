import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_elo_tier.dart';

/// Reusable ELO Division Tier Badge displaying rank tier, custom glow, and seasonal XP bonus.
class QuizDuelEloTierBadge extends StatelessWidget {
  const QuizDuelEloTierBadge({
    required this.elo,
    this.compact = false,
    this.showXpBonus = false,
    super.key,
  });

  final int elo;
  final bool compact;
  final bool showXpBonus;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final tier = QuizDuelEloTier.fromElo(elo);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tier.color.withAlpha(isDark ? 45 : 25),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(
          color: tier.color.withAlpha(isDark ? 80 : 50),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: tier.color.withAlpha(isDark ? 50 : 25),
            blurRadius: compact ? 4 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tier.label,
            style: typography.caption.bold.copyWith(
              color: isDark ? colors.white : tier.color,
              fontSize: compact ? 11 : 12.5,
              letterSpacing: 0.2,
            ),
          ),
          if (showXpBonus) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: colors.warning.withAlpha(isDark ? 50 : 30),
                borderRadius: AppRadius.radiusMicro,
              ),
              child: Text(
                '+${tier.seasonalRewardXp} XP',
                style: typography.caption.bold.copyWith(
                  color: colors.warning,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
