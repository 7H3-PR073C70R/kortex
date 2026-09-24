import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

class LeaderboardScholarSheet extends StatelessWidget {
  const LeaderboardScholarSheet({
    required this.entry,
    super.key,
  });

  final LeaderboardEntryEntity entry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.gray.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            AppAvatar(
              customDimension: 80,
              imageUrl: entry.avatarUrl,
              name: entry.userName,
            ),
            const SizedBox(height: 16),
            Text(
              entry.userName,
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.syllabotAccent.withAlpha(30),
                borderRadius: AppRadius.radiusBadge,
              ),
              child: Text(
                entry.track,
                style: typography.caption.bold.copyWith(
                  color: colors.syllabotAccent,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  icon: '⚡',
                  value: '${entry.weeklyXp}',
                  label: 'Weekly XP',
                ),
                _StatItem(
                  icon: '🔥',
                  value: '${entry.streakDays}d',
                  label: 'Streak',
                ),
                _StatItem(
                  icon: '🏆',
                  value: entry.leagueTier,
                  label: 'League',
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  unawaited(HapticFeedback.heavyImpact());
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusCard,
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Send Cheers 🎉',
                  style: typography.body.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final String icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      children: [
        Text(icon, style: context.typography.body.regular.copyWith(fontSize: 24)),
        const SizedBox(height: 8),
        Text(
          value,
          style: typography.subhead.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}
