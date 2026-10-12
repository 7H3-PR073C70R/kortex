import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_elo_tier_badge.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_leaderboard_sheet.dart';

/// Top header for the 1v1 Quiz Duel matchmaking modal sheet.
class QuizDuelMatchmakingHeader extends StatelessWidget {
  const QuizDuelMatchmakingHeader({
    required this.userElo,
    required this.isDesktop,
    super.key,
  });

  final int userElo;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          if (!isDesktop) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadius.micro),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Title & ELO Banner Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.primary, colors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '1v1 Academic Duel',
                            style: typography.title2.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => QuizDuelLeaderboardSheet.show(context),
                          child: QuizDuelEloTierBadge(
                            elo: userElo,
                            compact: true,
                            showXpBonus: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Real-time battle of speed and academic mastery.',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
