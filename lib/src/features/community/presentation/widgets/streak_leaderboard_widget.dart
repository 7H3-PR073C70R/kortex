import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

class StreakLeaderboardWidget extends StatelessWidget {
  const StreakLeaderboardWidget({
    required this.entries,
    this.streakFreezeCount = 0,
    super.key,
  });

  final List<LeaderboardEntryEntity> entries;
  final int streakFreezeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final goldColor = colors.warning;
    final silverColor = colors.gray;
    final bronzeColor = colors.recallHard;

    final currentUserEntry =
        entries.where((e) => e.isCurrentUser).firstOrNull;
    final currentTier = currentUserEntry?.leagueTier ?? 'Bronze';

    return Semantics(
      label: l10n.yourPosition,
      child: Column(
        children: [
          // Weekly League Tier & Streak Freeze Status Banner
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getTierGradient(currentTier, colors, isDark),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getTierBorderColor(currentTier, colors),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getTierEmoji(currentTier),
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$currentTier League',
                              style: typography.subhead.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            Text(
                              'Top 20% promoted every Monday at 00:00 UTC',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Weekly',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                if (streakFreezeCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent.withAlpha(isDark ? 35 : 20),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.syllabotAccent.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🛡️', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          "$streakFreezeCount Streak Freeze Active • Missed days won't reset your streak",
                          style: typography.caption.bold.copyWith(
                            color: colors.syllabotAccent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Current User Standing Highlight Card
          if (currentUserEntry != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary,
                    ),
                    child: Center(
                      child: Text(
                        '#${currentUserEntry.rank}',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                currentUserEntry.userName,
                                style: typography.footnote.bold.copyWith(
                                  color: colors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.yourPosition,
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.dailyStreakRank(
                            currentUserEntry.rank,
                            currentUserEntry.streakDays,
                          ),
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${currentUserEntry.weeklyXp} XP',
                      style: typography.caption.bold.copyWith(
                        color: colors.syllabotAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Podium (Top 3) if available
          if (entries.length >= 3)
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withAlpha(isDark ? 50 : 25),
                    colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 60 : 35),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Rank 2
                  _PodiumAvatar(
                    entry: entries[1],
                    place: 2,
                    color: silverColor,
                    height: 80,
                  ),
                  // Rank 1
                  _PodiumAvatar(
                    entry: entries[0],
                    place: 1,
                    color: goldColor,
                    height: 110,
                  ),
                  // Rank 3
                  _PodiumAvatar(
                    entry: entries[2],
                    place: 3,
                    color: bronzeColor,
                    height: 65,
                  ),
                ],
              ),
            ),

          // Scrollable Rank List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final isTopThree = index < 3;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: entry.isCurrentUser
                      ? colors.primary.withAlpha(isDark ? 40 : 20)
                      : (isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: entry.isCurrentUser
                        ? colors.primary
                        : colors.primary.withAlpha(isDark ? 30 : 15),
                  ),
                ),
                child: Row(
                  children: [
                    // Rank badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isTopThree
                            ? (index == 0
                                  ? goldColor.withAlpha(50)
                                  : index == 1
                                  ? silverColor.withAlpha(50)
                                  : bronzeColor.withAlpha(50))
                            : colors.surfaceSecondary.withAlpha(100),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: typography.caption.bold.copyWith(
                            color: isTopThree
                                ? (index == 0
                                      ? goldColor
                                      : index == 1
                                      ? silverColor
                                      : bronzeColor)
                                : colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // User Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.userName,
                                  style: typography.footnote.bold.copyWith(
                                    color: colors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _getTierBorderColor(entry.leagueTier, colors).withAlpha(30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_getTierEmoji(entry.leagueTier)} ${entry.leagueTier}',
                                  style: typography.caption.bold.copyWith(
                                    fontSize: 9.5,
                                    color: _getTierBorderColor(entry.leagueTier, colors),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.dailyStreakRank(index + 1, entry.streakDays),
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // XP Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.syllabotAccent.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.weeklyXp} XP',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Color> _getTierGradient(String tier, AppThemeColorsExtension colors, bool isDark) {
    switch (tier.toLowerCase()) {
      case "dean's list":
        return [
          colors.primary.withAlpha(isDark ? 80 : 50),
          colors.syllabotAccent.withAlpha(isDark ? 60 : 35),
        ];
      case 'diamond':
        return [
          colors.info.withAlpha(isDark ? 70 : 40),
          colors.primary.withAlpha(isDark ? 50 : 25),
        ];
      case 'gold':
        return [
          colors.warning.withAlpha(isDark ? 60 : 35),
          colors.primary.withAlpha(isDark ? 40 : 20),
        ];
      case 'silver':
        return [
          colors.gray.withAlpha(isDark ? 50 : 25),
          colors.surfaceSecondary,
        ];
      case 'bronze':
      default:
        return [
          colors.recallHard.withAlpha(isDark ? 50 : 25),
          colors.surfaceSecondary,
        ];
    }
  }

  Color _getTierBorderColor(String tier, AppThemeColorsExtension colors) {
    switch (tier.toLowerCase()) {
      case "dean's list":
        return colors.syllabotAccent;
      case 'diamond':
        return colors.info;
      case 'gold':
        return colors.warning;
      case 'silver':
        return colors.gray;
      case 'bronze':
      default:
        return colors.recallHard;
    }
  }

  String _getTierEmoji(String tier) {
    switch (tier.toLowerCase()) {
      case "dean's list":
        return '🏆';
      case 'diamond':
        return '💎';
      case 'gold':
        return '🥇';
      case 'silver':
        return '🥈';
      case 'bronze':
      default:
        return '🥉';
    }
  }
}

class _PodiumAvatar extends StatelessWidget {
  const _PodiumAvatar({
    required this.entry,
    required this.place,
    required this.color,
    required this.height,
  });

  final LeaderboardEntryEntity entry;
  final int place;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            AppAvatar(
              customDimension: place == 1 ? 56 : 44,
              imageUrl: entry.avatarUrl,
              name: entry.userName,
              backgroundColor: color.withAlpha(50),
              foregroundColor: colors.textPrimary,
              borderColor: color,
              borderWidth: 2,
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
              child: Text(
                '$place',
                style: typography.caption.bold.copyWith(
                  fontSize: 10,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          entry.userName.split(' ').first,
          style: typography.caption.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        Text(
          '${entry.weeklyXp} XP',
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            color: color.withAlpha(40),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border.all(color: color.withAlpha(100)),
          ),
        ),
      ],
    );
  }
}
