import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/leaderboard/leaderboard_hero_tier_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/leaderboard/leaderboard_podium_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/leaderboard/leaderboard_rank_card.dart';
import 'package:kortex/src/l10n/l10n.dart';

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
    final l10n = context.l10n;

    final currentUserEntry = entries.where((e) => e.isCurrentUser).firstOrNull;
    final currentTier = currentUserEntry?.leagueTier ?? 'Bronze';

    return Semantics(
      label: l10n.yourPosition,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LeaderboardHeroTierCard(
            currentTier: currentTier,
            streakFreezeCount: streakFreezeCount,
          ),
          const SizedBox(height: 24),
          
          if (entries.length >= 3)
            LeaderboardPodiumWidget(entries: entries.take(3).toList()),
            
          const SizedBox(height: 8),
          
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              
              // Zone dividers
              Widget? divider;
              if (index == 5) { // Assuming top 5 are promotion zone
                divider = _ZoneDivider(
                  label: 'Promotion Zone (Top 20%)',
                  color: colors.success,
                );
              } else if (index == 18) { // Assuming bottom 10%
                divider = _ZoneDivider(
                  label: 'Demotion Zone (Bottom 10%)',
                  color: colors.error,
                );
              }
              
              return Column(
                children: [
                  if (divider != null) ...[
                    divider,
                    const SizedBox(height: 12),
                  ],
                  LeaderboardRankCard(entry: entry, index: index),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ZoneDivider extends StatelessWidget {
  const _ZoneDivider({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    
    return Row(
      children: [
        Expanded(child: Divider(color: color.withAlpha(50), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: typography.caption.bold.copyWith(color: color),
          ),
        ),
        Expanded(child: Divider(color: color.withAlpha(50), thickness: 1)),
      ],
    );
  }
}
