import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_league_rules_sheet.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/streak_freeze_shield_sheet.dart';

/// Top hero card highlighting the active league division, weekly countdown,
/// and fast-access streak freeze shield equipping.
class LeaderboardHeroTierCard extends StatefulWidget {
  const LeaderboardHeroTierCard({
    required this.currentTier,
    this.streakFreezeCount = 0,
    super.key,
  });

  final String currentTier;
  final int streakFreezeCount;

  @override
  State<LeaderboardHeroTierCard> createState() => _LeaderboardHeroTierCardState();
}

class _LeaderboardHeroTierCardState extends State<LeaderboardHeroTierCard> {
  Timer? _timer;
  late Duration _timeRemaining;

  @override
  void initState() {
    super.initState();
    _timeRemaining = _calculateTimeUntilReset();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _timeRemaining = _calculateTimeUntilReset();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration _calculateTimeUntilReset() {
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
    final diff = nextMondayUtc.difference(now.toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  String _formatCountdown(Duration duration) {
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    if (days > 0) {
      return '${days}d ${hours}h left';
    }
    return '${hours}h ${minutes}m left';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.selectionClick());
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            backgroundColor: context.colors.transparent,
            isScrollControlled: true,
            builder: (context) => const LeaderboardLeagueRulesSheet(),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _getTierGradient(widget.currentTier, colors, isDark),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.radiusPanel,
          border: Border.all(
            color: _getTierBorderColor(widget.currentTier, colors),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _getTierBorderColor(widget.currentTier, colors)
                  .withAlpha(isDark ? 30 : 15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceElevated.withAlpha(160)
                            : colors.white.withAlpha(180),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(isDark ? 40 : 10),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Text(
                        _getTierEmoji(widget.currentTier),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${widget.currentTier} League',
                              style: typography.subhead.bold.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(isDark ? 50 : 25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 10,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _formatCountdown(_timeRemaining),
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 9.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
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

                // Rules & Prizes Trigger
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceElevated.withAlpha(200)
                        : colors.white.withAlpha(220),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.surfaceBorder.withAlpha(isDark ? 70 : 40),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Rules',
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (widget.streakFreezeCount >= 0) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  unawaited(StreakFreezeShieldSheet.show(context));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 35 : 20),
                    borderRadius: AppRadius.radiusBadge,
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '🛡️',
                        style: typography.caption.regular.copyWith(
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.streakFreezeCount} Streak Freeze Shield${widget.streakFreezeCount == 1 ? "" : "s"} • Tap to protect streak',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
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
    return 'Resets Mon $formattedHour:$minuteStr $period';
  }
}
