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

    return Semantics(
      label: 'Leaderboard Rankings',
      child: Column(
        children: [
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
                    color: Colors.grey.shade400,
                    height: 80,
                  ),
                  // Rank 1
                  _PodiumAvatar(
                    entry: entries[0],
                    place: 1,
                    color: Colors.amber,
                    height: 110,
                  ),
                  // Rank 3
                  _PodiumAvatar(
                    entry: entries[2],
                    place: 3,
                    color: Colors.brown.shade300,
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
                                  ? Colors.amber.withAlpha(50)
                                  : index == 1
                                  ? Colors.grey.withAlpha(50)
                                  : Colors.brown.withAlpha(50))
                            : colors.surfaceSecondary.withAlpha(100),
                      ),
                      child: Center(
                        child: Text(
                          '#${index + 1}',
                          style: typography.caption.bold.copyWith(
                            color: isTopThree
                                ? (index == 0
                                      ? Colors.amber
                                      : index == 1
                                      ? Colors.grey.shade400
                                      : Colors.brown.shade400)
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
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
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
