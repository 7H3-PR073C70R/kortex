import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Explainer banner describing the purpose and core mechanics of Study Pods.
class StudyCirclesExplainerBanner extends StatelessWidget {
  const StudyCirclesExplainerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withAlpha(isDark ? 28 : 14),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 45 : 25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.groups_rounded,
                size: 20,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'What are Study Pods?',
                style: typography.subhead.bold.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Study Pods are small peer study groups of up to 6 scholars taking the same track. Join a pod to commit to a collective weekly focus target, monitor contributions, and send instant nudges to keep each other accountable.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFeatureChip(
                context,
                Icons.people_outline_rounded,
                'Max 6 Scholars',
              ),
              _buildFeatureChip(
                context,
                Icons.timer_outlined,
                'Weekly Quests',
              ),
              _buildFeatureChip(
                context,
                Icons.bolt_rounded,
                'Instant Nudges',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary,
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 30 : 15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
