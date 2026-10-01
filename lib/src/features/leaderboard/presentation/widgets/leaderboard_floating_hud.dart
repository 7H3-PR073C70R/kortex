import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

/// Floating dynamic island HUD showcasing the current user's live position,
/// live XP, streak flame badge, and fast jump-to navigation with spring physics.
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

    final entry = currentUserEntry!;
    var xpToPass = 0;
    if (nextUserEntry != null) {
      xpToPass = nextUserEntry!.weeklyXp - entry.weeklyXp + 1;
    }

    final isPromotionZone = entry.rank <= 5;
    final isDemotionZone = entry.rank >= 18;
    final effectiveStreak = entry.streakDays > 0 ? entry.streakDays : 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceElevated.withAlpha(220)
                : colors.surfacePrimary.withAlpha(235),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 110 : 70),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.primary.withAlpha(isDark ? 45 : 20),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 60 : 15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with Rank Overlap Pill
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AppAvatar(
                    customDimension: 44,
                    imageUrl: entry.avatarUrl,
                    name: entry.userName,
                    borderColor: colors.primary,
                    borderWidth: 2,
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            colors.primary.withAlpha(200),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? colors.surfaceElevated : colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '#${entry.rank}',
                        style: typography.caption.bold.copyWith(
                          fontSize: 9.5,
                          color: colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // Metrics Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // XP Badge
                        Text(
                          '${entry.weeklyXp} XP',
                          style: typography.subhead.bold.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Prominent Streak Badge in Floating HUD
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF5722), Color(0xFFFF9800)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🔥',
                                style: typography.caption.regular.copyWith(
                                  fontSize: 9.5,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${effectiveStreak}d',
                                style: typography.caption.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Zone Status
                        if (isPromotionZone)
                          Flexible(
                            child: Text(
                              '🚀 Promotion',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.bold.copyWith(
                                color: colors.success,
                                fontSize: 10,
                              ),
                            ),
                          )
                        else if (isDemotionZone)
                          Flexible(
                            child: Text(
                              '⚠️ Demotion',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.bold.copyWith(
                                color: colors.error,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),

                    // Contextual Gap to Overtake
                    if (xpToPass > 0 && nextUserEntry != null)
                      Text(
                        '+$xpToPass XP to pass ${nextUserEntry!.userName.split(' ').first} (#${nextUserEntry!.rank})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      )
                    else if (entry.rank == 1)
                      Text(
                        '👑 Current League Leader! Keep pushing!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.bold.copyWith(
                          color: const Color(0xFFFFB300),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Interactive "Jump To My Rank" Action Button
              GestureDetector(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onJumpToMe();
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colors.primary,
                        colors.primary.withAlpha(200),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(80),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.arrow_downward_rounded,
                    color: colors.white,
                    size: 18,
                  )
                      .animate(
                        onPlay: (controller) =>
                            controller.repeat(reverse: true),
                      )
                      .moveY(
                        begin: -2,
                        end: 2,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeInOut,
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
