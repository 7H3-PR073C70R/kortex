import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_hero_tier_card.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_podium_widget.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_rank_card.dart';
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
          // ── Top League Hero Tier Card ─────────────────────────────────
          LeaderboardHeroTierCard(
            currentTier: currentTier,
            streakFreezeCount: streakFreezeCount,
          )
              .animate()
              .fadeIn(duration: const Duration(milliseconds: 250))
              .slideY(begin: -0.04, end: 0, curve: Curves.easeOutQuint),

          const SizedBox(height: 12),

          // ── Prestigious 3D Podium for Top 3 ───────────────────────────
          if (entries.isNotEmpty)
            LeaderboardPodiumWidget(entries: entries.take(3).toList()),

          const SizedBox(height: 12),

          // ── Full Leaderboard List with Staggered Animations ───────────
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];

              // Zone dividers
              Widget? divider;
              if (index == 5) {
                divider = _ZoneDivider(
                  label: 'Promotion Zone (Top 20%)',
                  icon: Icons.rocket_launch_rounded,
                  color: colors.success,
                );
              } else if (index == 18) {
                divider = _ZoneDivider(
                  label: 'Relegation Zone (Bottom 10%)',
                  icon: Icons.warning_amber_rounded,
                  color: colors.error,
                );
              }

              final delayMs = (index * 35).clamp(0, 500);

              return Column(
                children: [
                  if (divider != null) ...[
                    const SizedBox(height: 8),
                    divider,
                    const SizedBox(height: 14),
                  ],
                  LeaderboardRankCard(entry: entry, index: index)
                      .animate(delay: Duration(milliseconds: delayMs))
                      .fadeIn(duration: const Duration(milliseconds: 200))
                      .slideY(
                        begin: 0.04,
                        end: 0,
                        curve: Curves.easeOutQuint,
                      ),
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
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withAlpha(0),
                  color.withAlpha(isDark ? 80 : 50),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(isDark ? 30 : 15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withAlpha(isDark ? 70 : 40),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: typography.caption.bold.copyWith(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withAlpha(isDark ? 80 : 50),
                  color.withAlpha(0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
