import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

class LeaderboardLeagueRulesSheet extends StatelessWidget {
  const LeaderboardLeagueRulesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 520,
      builder: (_) => const LeaderboardLeagueRulesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceElevated : colors.surfacePrimary,
        borderRadius: isDesktop
            ? BorderRadius.circular(AppRadius.dialog)
            : const BorderRadius.vertical(
                top: Radius.circular(AppRadius.dialog),
              ),
        boxShadow: isDesktop
            ? [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 80 : 30),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDesktop) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: colors.gray.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'League Rules & Prizes',
                  style: typography.title2.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                if (isDesktop)
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colors.textMuted,
                    tooltip: 'Close',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            _RuleItem(
              icon: '🚀',
              title: 'Promotion Zone',
              description: 'Finish in the top 20% to advance to the next tier.',
              color: colors.success,
            ),
            const SizedBox(height: 16),
            _RuleItem(
              icon: '⚠️',
              title: 'Demotion Zone',
              description: 'Finish in the bottom 10% and you will drop a tier.',
              color: colors.error,
            ),
            const SizedBox(height: 16),
            _RuleItem(
              icon: '⏱️',
              title: 'Weekly Reset',
              description: 'Leagues reset every Monday. XP starts fresh.',
              color: colors.primary,
            ),
            const SizedBox(height: 16),
            _RuleItem(
              icon: '🛡️',
              title: 'Streak Freeze',
              description: 'Keeps your streak alive if you miss a day. Unrelated to XP.',
              color: colors.syllabotAccent,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final String icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: AppRadius.radiusCard,
          ),
          child: Text(icon, style: context.typography.body.regular.copyWith(fontSize: 20)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: typography.body.regular.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
