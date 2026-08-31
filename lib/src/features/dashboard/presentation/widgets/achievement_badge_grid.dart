import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

class AchievementBadgeItem {
  const AchievementBadgeItem({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.progress,
    required this.target,
    required this.isUnlocked,
  });

  final String key;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final int progress;
  final int target;
  final bool isUnlocked;

  double get progressRatio =>
      target == 0 ? 1.0 : (progress / target).clamp(0.0, 1.0);
}

class AchievementBadgeGrid extends StatelessWidget {
  const AchievementBadgeGrid({
    this.badges,
    super.key,
  });

  final List<AchievementBadgeItem>? badges;

  List<AchievementBadgeItem> _getDefaultBadges(BuildContext context) {
    final l10n = context.l10n;
    return [
      AchievementBadgeItem(
        key: 'night_owl',
        title: l10n.badgeNightOwlTitle,
        description: l10n.badgeNightOwlDesc,
        icon: Icons.nightlight_round,
        accentColor: Colors.deepPurpleAccent,
        progress: 5,
        target: 5,
        isUnlocked: true,
      ),
      AchievementBadgeItem(
        key: 'century_club',
        title: l10n.badgeCenturyClubTitle,
        description: l10n.badgeCenturyClubDesc,
        icon: Icons.military_tech_rounded,
        accentColor: Colors.amberAccent,
        progress: 100,
        target: 100,
        isUnlocked: true,
      ),
      AchievementBadgeItem(
        key: 'streak_master',
        title: l10n.badgeStreakMasterTitle,
        description: l10n.badgeStreakMasterDesc,
        icon: Icons.whatshot_rounded,
        accentColor: Colors.orangeAccent,
        progress: 9,
        target: 14,
        isUnlocked: false,
      ),
      AchievementBadgeItem(
        key: 'stem_alchemist',
        title: l10n.badgeStemAlchemistTitle,
        description: l10n.badgeStemAlchemistDesc,
        icon: Icons.functions_rounded,
        accentColor: Colors.greenAccent,
        progress: 32,
        target: 50,
        isUnlocked: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = context.l10n;
    final badgeList = badges ?? _getDefaultBadges(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.achievementsGridTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badgeList.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.95,
            ),
            itemBuilder: (context, index) {
              final badge = badgeList[index];
              return _BadgeCard(badge: badge);
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({
    required this.badge,
  });

  final AchievementBadgeItem badge;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    final badgeColor = badge.isUnlocked ? badge.accentColor : Colors.white38;
    final bgColor = badge.isUnlocked
        ? badge.accentColor.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.04);

    final statusText = badge.isUnlocked
        ? 'Unlocked'
        : 'Progress: ${badge.progress} of ${badge.target}';

    return Semantics(
      label: '${badge.title}. ${badge.description}. $statusText',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: badge.isUnlocked
                ? badge.accentColor.withValues(alpha: 0.4)
                : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(badge.icon, color: badgeColor, size: 22),
                ),
                if (badge.isUnlocked)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 18,
                  )
                else
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: badge.isUnlocked ? Colors.white : Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!badge.isUnlocked) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: badge.progressRatio,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(badge.accentColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${badge.progress} / ${badge.target}',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white38,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              const Text(
                'COMPLETED',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
