import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

class StreakLeaderboardWidget extends StatelessWidget {
  const StreakLeaderboardWidget({
    required this.entries,
    super.key,
  });

  final List<LeaderboardEntryEntity> entries;

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

    return Semantics(
      label: l10n.yourPosition,
      child: Column(
        children: [
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
                          Text(
                            entry.userName,
                            style: typography.footnote.bold.copyWith(
                              color: colors.textPrimary,
                            ),
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
