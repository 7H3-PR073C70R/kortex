import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

class LeaderboardFloatingHud extends StatelessWidget {
  const LeaderboardFloatingHud({
    required this.currentUserEntry,
    required this.nextUserEntry,
    required this.onJumpToMe,
    super.key,
  });

  final LeaderboardEntryEntity? currentUserEntry;
  final LeaderboardEntryEntity? nextUserEntry;
  final VoidCallback onJumpToMe;

  @override
  Widget build(BuildContext context) {
    if (currentUserEntry == null) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    var xpToPass = 0;
    if (nextUserEntry != null) {
      xpToPass = nextUserEntry!.weeklyXp - currentUserEntry!.weeklyXp + 1;
    }
    
    final isPromotionZone = currentUserEntry!.rank <= 5; // Top 20%
    final isDemotionZone = currentUserEntry!.rank >= 18; // Bottom 10%

    return ClipRRect(
      borderRadius: AppRadius.radiusPanel,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceElevated.withAlpha(200) : colors.white.withAlpha(200),
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 80 : 40),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(isDark ? 30 : 15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    customDimension: 44,
                    imageUrl: currentUserEntry!.avatarUrl,
                    name: currentUserEntry!.userName,
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? colors.surfaceElevated : colors.white, width: 2),
                      ),
                      child: Text(
                        '#${currentUserEntry!.rank}',
                        style: typography.caption.bold.copyWith(
                          fontSize: 10,
                          color: colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${currentUserEntry!.weeklyXp} XP',
                          style: typography.footnote.bold.copyWith(
                            color: colors.textPrimary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        if (isPromotionZone) ...[
                          const SizedBox(width: 8),
                          Text(
                            '🚀 Promotion Zone',
                            style: typography.caption.bold.copyWith(
                              color: colors.success,
                              fontSize: 10,
                            ),
                          ),
                        ] else if (isDemotionZone) ...[
                          const SizedBox(width: 8),
                          Text(
                            '⚠️ Demotion Zone',
                            style: typography.caption.bold.copyWith(
                              color: colors.error,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (xpToPass > 0 && nextUserEntry != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '+$xpToPass XP to pass ${nextUserEntry!.userName.split(' ').first} (#${nextUserEntry!.rank})',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onJumpToMe();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: colors.primary,
                    size: 20,
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
