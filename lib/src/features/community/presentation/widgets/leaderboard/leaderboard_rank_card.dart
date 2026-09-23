import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/leaderboard/leaderboard_scholar_sheet.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class LeaderboardRankCard extends StatelessWidget {
  const LeaderboardRankCard({
    required this.entry,
    required this.index,
    super.key,
  });

  final LeaderboardEntryEntity entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    
    final isDemotion = index >= 18; // Bottom 10% assuming ~20 users total
    
    final goldColor = colors.warning;
    final silverColor = colors.gray;
    final bronzeColor = colors.recallHard;
    
    Color getRankColor() {
      if (index == 0) return goldColor;
      if (index == 1) return silverColor;
      if (index == 2) return bronzeColor;
      if (isDemotion) return colors.error;
      return colors.textSecondary;
    }

    return GestureDetector(
      onTap: () {
        unawaited(HapticFeedback.lightImpact());
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: context.colors.transparent,
            builder: (context) => LeaderboardScholarSheet(entry: entry),
          ),
        );
      },
      child: PlatformHoverBuilder(
        builder: (context, isItemHovered, child) => AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: entry.isCurrentUser
                ? colors.primary.withAlpha(
                    isDark
                        ? (isItemHovered ? 55 : 40)
                        : (isItemHovered ? 30 : 20),
                  )
                : isItemHovered
                ? (isDark
                      ? colors.surfaceElevated
                      : colors.surfaceSecondary)
                : (isDark
                      ? colors.surfaceSecondary
                      : colors.surfacePrimary),
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: entry.isCurrentUser
                  ? colors.primary
                  : isItemHovered
                  ? colors.primary.withAlpha(isDark ? 80 : 50)
                  : isDemotion 
                    ? colors.error.withAlpha(50)
                    : colors.primary.withAlpha(isDark ? 30 : 15),
              width: entry.isCurrentUser || isItemHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(
                  isDark
                      ? (isItemHovered ? 30 : 10)
                      : (isItemHovered ? 12 : 4),
                ),
                blurRadius: isItemHovered ? 8 : 4,
                offset: Offset(0, isItemHovered ? 2 : 1),
              ),
            ],
          ),
          child: Row(
            children: [
              // Rank badge
              SizedBox(
                width: 32,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: typography.subhead.bold.copyWith(
                      color: getRankColor(),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // User Info
              AppAvatar(
                customDimension: 40,
                imageUrl: entry.avatarUrl,
                name: entry.userName,
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
                            entry.userName,
                            style: typography.footnote.bold.copyWith(
                              color: entry.isCurrentUser ? colors.primary : colors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (entry.isCurrentUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: AppRadius.radiusMicro,
                            ),
                            child: Text(
                              'YOU',
                              style: typography.caption.bold.copyWith(
                                fontSize: 9,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '🔥 ${entry.streakDays}d',
                          style: typography.caption.bold.copyWith(
                            color: colors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          entry.track,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
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
                  color: entry.isCurrentUser 
                    ? colors.primary.withAlpha(isDark ? 80 : 30)
                    : colors.syllabotAccent.withAlpha(isDark ? 40 : 25),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Text(
                  '⚡ ${entry.weeklyXp}',
                  style: typography.caption.bold.copyWith(
                    color: entry.isCurrentUser ? colors.primary : colors.syllabotAccent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
