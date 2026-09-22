import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/community/presentation/widgets/leaderboard/leaderboard_league_rules_sheet.dart';

class LeaderboardHeroTierCard extends StatelessWidget {
  const LeaderboardHeroTierCard({
    required this.currentTier,
    this.streakFreezeCount = 0,
    super.key,
  });

  final String currentTier;
  final int streakFreezeCount;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => const LeaderboardLeagueRulesSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getTierGradient(currentTier, colors, isDark),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.radiusPanel,
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
                          _formatWeeklyResetLocalTime(),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 40 : 25),
                    borderRadius: AppRadius.radiusMicro,
                  ),
                  child: Text(
                    'Rules & Prizes',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colors.syllabotAccent.withAlpha(isDark ? 35 : 20),
                  borderRadius: AppRadius.radiusBadge,
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
                      "$streakFreezeCount Streak Freeze Active",
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
    );
  }

  List<Color> _getTierGradient(
    String tier,
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
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

  String _formatWeeklyResetLocalTime() {
    final now = DateTime.now();
    var daysUntilMonday = (DateTime.monday - now.toUtc().weekday) % 7;
    if (daysUntilMonday == 0 &&
        (now.toUtc().hour > 0 || now.toUtc().minute > 0)) {
      daysUntilMonday = 7;
    }
    final nextMondayUtc = DateTime.utc(
      now.toUtc().year,
      now.toUtc().month,
      now.toUtc().day + daysUntilMonday,
    );
    final localTime = nextMondayUtc.toLocal();
    final hour = localTime.hour;
    final minute = localTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = (hour % 12 == 0) ? 12 : hour % 12;
    final minuteStr = minute == 0 ? '00' : minute.toString().padLeft(2, '0');
    return 'Resets on Mon at $formattedHour:$minuteStr $period';
  }
}
