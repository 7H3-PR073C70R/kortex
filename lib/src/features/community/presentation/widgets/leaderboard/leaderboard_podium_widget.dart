import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/features/community/presentation/widgets/leaderboard/leaderboard_scholar_sheet.dart';

class LeaderboardPodiumWidget extends StatelessWidget {
  const LeaderboardPodiumWidget({
    required this.entries,
    super.key,
  });

  final List<LeaderboardEntryEntity> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final isDark = context.isDarkMode;
    
    final goldColor = colors.warning;
    final silverColor = colors.gray;
    final bronzeColor = colors.recallHard;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.only(top: 24, bottom: 0, left: 16, right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withAlpha(isDark ? 30 : 15),
            colors.syllabotAccent.withAlpha(isDark ? 20 : 10),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 40 : 20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (entries.length >= 2)
            _PodiumPedestal(
              entry: entries[1],
              place: 2,
              color: silverColor,
              height: 90,
              delay: const Duration(milliseconds: 100),
            ),
          if (entries.isNotEmpty)
            _PodiumPedestal(
              entry: entries[0],
              place: 1,
              color: goldColor,
              height: 120,
              delay: Duration.zero,
              isFirst: true,
            ),
          if (entries.length >= 3)
            _PodiumPedestal(
              entry: entries[2],
              place: 3,
              color: bronzeColor,
              height: 70,
              delay: const Duration(milliseconds: 200),
            ),
        ],
      ),
    );
  }
}

class _PodiumPedestal extends StatelessWidget {
  const _PodiumPedestal({
    required this.entry,
    required this.place,
    required this.color,
    required this.height,
    required this.delay,
    this.isFirst = false,
  });

  final LeaderboardEntryEntity entry;
  final int place;
  final Color color;
  final double height;
  final Duration delay;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => LeaderboardScholarSheet(entry: entry),
        );
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Stack(
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            children: [
              AppAvatar(
                customDimension: isFirst ? 64 : 48,
                imageUrl: entry.avatarUrl,
                name: entry.userName,
                backgroundColor: color.withAlpha(50),
                foregroundColor: colors.textPrimary,
                borderColor: color,
                borderWidth: isFirst ? 3 : 2,
              ),
              if (isFirst)
                Positioned(
                  top: -16,
                  child: const Text('👑', style: TextStyle(fontSize: 24))
                      .animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: const Duration(seconds: 2)),
                ),
              Positioned(
                bottom: -8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.radiusMicro,
                    border: Border.all(color: colors.backgroundPrimary, width: 2),
                  ),
                  child: Text(
                    '$place',
                    style: typography.caption.bold.copyWith(
                      fontSize: 10,
                      color: colors.backgroundPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ).animate(delay: delay).scale(
                curve: AppMotion.easeOutCubic,
                duration: AppMotion.expressive,
              ),
          const SizedBox(height: 12),
          Text(
            entry.userName.split(' ').first,
            style: typography.footnote.bold.copyWith(
              color: colors.textPrimary,
            ),
          ).animate(delay: delay).fadeIn(),
          Text(
            '${entry.weeklyXp} XP',
            style: typography.caption.regular.copyWith(
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ).animate(delay: delay).fadeIn(),
          const SizedBox(height: 8),
          Container(
            width: 64,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withAlpha(80),
                  color.withAlpha(20),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card),
              ),
              border: Border.all(
                color: color.withAlpha(100),
                width: 1.5,
              ),
            ),
          ).animate(delay: delay).slideY(
                begin: 1,
                end: 0,
                curve: AppMotion.easeOutCubic,
                duration: AppMotion.expressive,
              ),
        ],
      ),
    );
  }
}
