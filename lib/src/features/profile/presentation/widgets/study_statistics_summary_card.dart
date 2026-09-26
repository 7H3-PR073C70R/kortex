import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Comprehensive Study Statistics Summary Card for the Profile Page.
/// Displays total study hours, cards mastered, XP points, and retention rates.
class StudyStatisticsSummaryCard extends StatelessWidget {
  const StudyStatisticsSummaryCard({
    this.profile,
    super.key,
  });

  final UserProfileEntity? profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final neural = context.neural;
    final isDark = context.isDarkMode;

    var totalCardsMastered = 0;
    var totalStudyTimeMins = 0;
    var xpPoints = profile?.xpPoints ?? 0;
    var retentionPct = ((profile?.retentionBenchmark ?? 0.85) * 100).toInt();

    try {
      if (locator.isRegistered<UserActivityService>()) {
        final userActivity = locator<UserActivityService>();
        totalCardsMastered = userActivity.getTotalCardsMastered();
        final summary = userActivity.getAnalyticsSummary();

        totalCardsMastered = mathMax(totalCardsMastered, summary.totalCardsMastered);
        totalStudyTimeMins = summary.weeklyMinutesStudied;
        xpPoints = mathMax(xpPoints, summary.xpPoints);
        if (summary.overallRetentionRate > 0) {
          retentionPct = (summary.overallRetentionRate * 100).toInt();
        }
      }
    } on Object catch (_) {}

    final studyHours = (totalStudyTimeMins / 60.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(color: colors.surfaceBorder),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: neural.amber400.withValues(alpha: isDark ? 0.15 : 0.1),
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Icon(
                        Icons.insights_rounded,
                        size: 16,
                        color: neural.amber400,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Study Analytics Summary',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color.fromRGBO(39, 39, 42, 0.9)
                      : colors.surfaceSecondary,
                  borderRadius: AppRadius.radiusMicro,
                  border: Border.all(color: colors.surfaceBorder),
                ),
                child: Text(
                  'Lifetime',
                  style: typography.caption.bold.copyWith(
                    color: colors.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Study Hours',
                  value: studyHours,
                  unit: 'hrs',
                  icon: Icons.timer_outlined,
                  color: neural.cyan400,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Cards Mastered',
                  value: '$totalCardsMastered',
                  unit: 'cards',
                  icon: Icons.check_circle_outline_rounded,
                  color: neural.emerald400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'Total XP',
                  value: '$xpPoints',
                  unit: 'xp',
                  icon: Icons.bolt_rounded,
                  color: const Color.fromRGBO(192, 132, 252, 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatTile(
                  label: 'Retention Rate',
                  value: '$retentionPct%',
                  unit: 'accuracy',
                  icon: Icons.psychology_outlined,
                  color: neural.amber400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  int mathMax(int a, int b) => a > b ? a : b;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isHovered
                ? colors.surfaceSecondary
                : (isDark
                    ? const Color.fromRGBO(18, 21, 28, 0.7)
                    : colors.surfaceSecondary.withValues(alpha: 0.5)),
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: isHovered
                  ? color.withValues(alpha: 0.4)
                  : colors.surfaceBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            value,
                            style: typography.title3.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 16,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            unit,
                            style: typography.caption.regular.copyWith(
                              color: colors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      label,
                      style: typography.caption.bold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
