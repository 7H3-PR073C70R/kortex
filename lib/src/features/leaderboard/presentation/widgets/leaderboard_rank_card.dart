import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_scholar_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

/// Ultra-polished leaderboard ranking card with interactive spring physics,
/// dynamic streak flame badges, multiplier indicators, and promotion zones.
class LeaderboardRankCard extends StatefulWidget {
  const LeaderboardRankCard({
    required this.entry,
    required this.index,
    super.key,
  });

  final LeaderboardEntryEntity entry;
  final int index;

  @override
  State<LeaderboardRankCard> createState() => _LeaderboardRankCardState();
}

class _LeaderboardRankCardState extends State<LeaderboardRankCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final entry = widget.entry;
    final rank = widget.index + 1;
    final isPromotion = rank <= 5;
    final isDemotion = rank >= 18;

    // Metallic colors for top ranks
    const goldColor = Color(0xFFFFB300);
    const silverColor = Color(0xFFB0BEC5);
    const bronzeColor = Color(0xFFBCAAA4);

    Color getRankColor() {
      if (rank == 1) return goldColor;
      if (rank == 2) return silverColor;
      if (rank == 3) return bronzeColor;
      if (isPromotion) return colors.success;
      if (isDemotion) return colors.error;
      return colors.textSecondary;
    }

    final effectiveStreak = entry.streakDays > 0
        ? entry.streakDays
        : (entry.weeklyXp > 0 ? 1 : 1);

    // Multiplier calculation for high streaks
    String? multiplierText;
    if (effectiveStreak >= 30) {
      multiplierText = '2.0x';
    } else if (effectiveStreak >= 14) {
      multiplierText = '1.75x';
    } else if (effectiveStreak >= 7) {
      multiplierText = '1.5x';
    } else if (effectiveStreak >= 4) {
      multiplierText = '1.25x';
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        unawaited(
          LeaderboardScholarSheet.show(context, entry: entry),
        );
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: entry.isCurrentUser
                ? colors.primary.withAlpha(isDark ? 45 : 22)
                : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: entry.isCurrentUser
                  ? colors.primary.withAlpha(isDark ? 180 : 120)
                  : rank == 1
                  ? goldColor.withAlpha(isDark ? 80 : 50)
                  : isPromotion
                  ? colors.success.withAlpha(isDark ? 50 : 30)
                  : isDemotion
                  ? colors.error.withAlpha(isDark ? 50 : 30)
                  : colors.surfaceBorder.withAlpha(isDark ? 60 : 40),
              width: entry.isCurrentUser ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: entry.isCurrentUser
                    ? colors.primary.withAlpha(isDark ? 30 : 15)
                    : colors.black.withAlpha(isDark ? 25 : 8),
                blurRadius: entry.isCurrentUser ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Rank Badge / Shield ─────────────────────────────────────
              _RankBadge(
                rank: rank,
                color: getRankColor(),
                isPromotion: isPromotion,
                isDemotion: isDemotion,
              ),

              const SizedBox(width: 12),

              // ── Scholar Avatar with ring ────────────────────────────────
              AppAvatar(
                customDimension: 42,
                imageUrl: entry.avatarUrl,
                name: entry.userName,
                borderColor: entry.isCurrentUser
                    ? colors.primary
                    : (rank <= 3 ? getRankColor().withAlpha(160) : null),
                borderWidth: entry.isCurrentUser || rank <= 3 ? 2 : 0,
              ),

              const SizedBox(width: 12),

              // ── Name & Streak / Track Details ───────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.userName,
                            style: typography.footnote.bold.copyWith(
                              color: entry.isCurrentUser
                                  ? colors.primary
                                  : colors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors.primary,
                                  colors.primary.withAlpha(200),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'YOU',
                              style: typography.caption.bold.copyWith(
                                fontSize: 9,
                                color: colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Streak Flame Pill + Track Pill
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          // Dynamic Flame Streak Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(
                                    0xFFFF5722,
                                  ).withAlpha(isDark ? 55 : 30),
                                  const Color(
                                    0xFFFF9800,
                                  ).withAlpha(isDark ? 40 : 20),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(
                                  0xFFFF9800,
                                ).withAlpha(isDark ? 90 : 50),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🔥',
                                  style: typography.caption.regular.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${effectiveStreak}d',
                                  style: typography.caption.bold.copyWith(
                                    color: const Color(0xFFFF9800),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                                if (multiplierText != null) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 3.5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF9800),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      multiplierText,
                                      style: typography.caption.bold.copyWith(
                                        color: Colors.black,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Track Label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceBorder.withAlpha(
                                isDark ? 40 : 20,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              entry.track,
                              style: typography.caption.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // ── XP Energy Badge ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: entry.isCurrentUser
                        ? [
                            colors.primary.withAlpha(isDark ? 90 : 40),
                            colors.primary.withAlpha(isDark ? 50 : 25),
                          ]
                        : [
                            colors.syllabotAccent.withAlpha(isDark ? 45 : 25),
                            colors.syllabotAccent.withAlpha(isDark ? 25 : 12),
                          ],
                  ),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: entry.isCurrentUser
                        ? colors.primary.withAlpha(isDark ? 140 : 80)
                        : colors.syllabotAccent.withAlpha(isDark ? 80 : 40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '⚡',
                      style: typography.caption.regular.copyWith(fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${entry.weeklyXp}',
                      style: typography.caption.bold.copyWith(
                        color: entry.isCurrentUser
                            ? colors.primary
                            : colors.syllabotAccent,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({
    required this.rank,
    required this.color,
    required this.isPromotion,
    required this.isDemotion,
  });

  final int rank;
  final Color color;
  final bool isPromotion;
  final bool isDemotion;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    if (rank == 1) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(80),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥇',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (rank == 2) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFECEFF1), Color(0xFFB0BEC5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(80),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥈',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (rank == 3) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(80),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '🥉',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    return SizedBox(
      width: 34,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$rank',
            style: typography.subhead.bold.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (isPromotion && rank <= 5)
            Text(
              '▲',
              style: typography.caption.bold.copyWith(
                color: const Color(0xFF4CAF50),
                fontSize: 8,
              ),
            )
          else if (isDemotion)
            Text(
              '▼',
              style: typography.caption.bold.copyWith(
                color: const Color(0xFFF44336),
                fontSize: 8,
              ),
            ),
        ],
      ),
    );
  }
}
