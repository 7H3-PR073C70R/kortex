import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

/// Live in-round split scoreboard header displaying player ratings, combo streaks,
/// rival locked status, and an animated tug-of-war momentum gauge.
class QuizDuelSplitScoreboardHeader extends StatelessWidget {
  const QuizDuelSplitScoreboardHeader({
    required this.myPlayer,
    required this.opponent,
    required this.rivalLocked,
    super.key,
  });

  final QuizDuelParticipant myPlayer;
  final QuizDuelParticipant opponent;
  final bool rivalLocked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final p1Pts = myPlayer.score;
    final p2Pts = opponent.score;
    final totalPts = max(1, p1Pts + p2Pts);
    final p1Share = (p1Pts / totalPts).clamp(0.10, 0.90);
    final delta = p1Pts - p2Pts;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: BorderRadius.circular(
          AppRadius.panel,
        ),
        border: Border.all(
          color: colors.surfaceBorder.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // My info
              Expanded(
                child: Row(
                  children: [
                    AppAvatar(
                      name: myPlayer.displayName,
                      customDimension: 36,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            myPlayer.displayName,
                            style: typography.caption.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${myPlayer.score} pts',
                            style: typography.body.bold.copyWith(
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (myPlayer.comboStreak > 1)
                      Text(
                        '🔥x${myPlayer.comboStreak}',
                        style: typography.caption.bold,
                      ),
                  ],
                ),
              ),
              // VS Center Badge
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                child: Text(
                  'VS',
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
              // Opponent info
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (opponent.comboStreak > 1)
                      Text(
                        '🔥x${opponent.comboStreak}',
                        style: typography.caption.bold,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            opponent.displayName,
                            style: typography.caption.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${opponent.score} pts',
                            style: typography.body.bold.copyWith(
                              color: colors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: AppMotion.snappy,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: rivalLocked
                            ? Border.all(
                                color: colors.success,
                                width: 2,
                              )
                            : null,
                        boxShadow: rivalLocked
                            ? [
                                BoxShadow(
                                  color: colors.success.withAlpha(140),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: AppAvatar(
                        name: opponent.displayName,
                        customDimension: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Live Tug-of-War Score Battle Gauge with Dynamic Delta Pill
          Stack(
            alignment: Alignment.center,
            children: [
              // Split Battle Gauge
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.micro),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (p1Share * 1000).round(),
                        child: AnimatedContainer(
                          duration: AppMotion.snappy,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.primary,
                                colors.primary.withAlpha(200),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 2,
                        color: colors.surfacePrimary,
                      ),
                      Expanded(
                        flex: ((1 - p1Share) * 1000).round(),
                        child: AnimatedContainer(
                          duration: AppMotion.snappy,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colors.secondary.withAlpha(200),
                                colors.secondary,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Floating Delta Indicator Pill in Center
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: colors.surfacePrimary,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                  border: Border.all(
                    color: delta > 0
                        ? colors.success
                        : delta < 0
                            ? colors.secondary
                            : colors.surfaceBorder,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 60 : 25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  delta > 0
                      ? '+$delta LEAD'
                      : delta < 0
                          ? '${delta.abs()} BEHIND'
                          : 'TIED',
                  style: typography.caption.bold.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.5,
                    color: delta > 0
                        ? colors.success
                        : delta < 0
                            ? colors.secondary
                            : colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
