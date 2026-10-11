import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// 4-Card Executive KPI Matrix.
class AnalyticsKpiGrid extends StatelessWidget {
  const AnalyticsKpiGrid({
    required this.analytics,
    this.timeframeIndex = 0,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;
  final int timeframeIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final overallRetention = (analytics.overallRetentionRate * 100).toInt();
    final hasRetention = overallRetention > 0;
    final hasCards = analytics.totalCardsMastered > 0;
    final hasStudyTime = analytics.weeklyMinutesStudied > 0;
    final hasStreak = analytics.currentStreakDays > 0;

    final String retentionSubtitle;
    if (!hasRetention) {
      retentionSubtitle = 'No review data yet';
    } else if (timeframeIndex == 0) {
      retentionSubtitle = 'Active Recall Rate (7d)';
    } else if (timeframeIndex == 1) {
      retentionSubtitle = '30-Day Mean Retention';
    } else {
      retentionSubtitle = 'All-Time Recall Index';
    }

    final String cardsSubtitle;
    if (!hasCards) {
      cardsSubtitle = '0 Active Cards';
    } else if (timeframeIndex == 0) {
      cardsSubtitle = '${analytics.totalCardsMastered} Active Cards (7d)';
    } else if (timeframeIndex == 1) {
      cardsSubtitle = '${analytics.totalCardsMastered} Active (30d)';
    } else {
      cardsSubtitle = '${analytics.totalCardsMastered} Total Mastered';
    }

    final String studyVelocityValue;
    if (analytics.weeklyMinutesStudied >= 120) {
      studyVelocityValue =
          '${(analytics.weeklyMinutesStudied / 60).toStringAsFixed(1)}h';
    } else {
      studyVelocityValue = '${analytics.weeklyMinutesStudied}m';
    }

    final String studyVelocitySubtitle;
    final weeklyHours = (analytics.weeklyMinutesStudied / 60).toStringAsFixed(
      1,
    );
    if (!hasStudyTime) {
      studyVelocitySubtitle = timeframeIndex == 0
          ? '0.0 hrs this week'
          : (timeframeIndex == 1 ? '0.0 hrs past 30d' : '0.0 hrs all time');
    } else if (timeframeIndex == 0) {
      studyVelocitySubtitle = '$weeklyHours hrs this week';
    } else if (timeframeIndex == 1) {
      studyVelocitySubtitle = '$weeklyHours hrs past 30d';
    } else {
      studyVelocitySubtitle = '$weeklyHours hrs all time';
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: KpiMetricCard(
                title: 'Retention Index',
                value: hasRetention ? '$overallRetention%' : '0%',
                subtitle: retentionSubtitle,
                badgeText: hasRetention ? 'Optimal' : 'Baseline',
                icon: Icons.psychology_rounded,
                accentColor: colors.success,
                colors: colors,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiMetricCard(
                title: 'Cards Mastered',
                value: '${analytics.totalCardsMastered}',
                subtitle: cardsSubtitle,
                badgeText: hasCards ? 'Active' : 'Empty',
                icon: Icons.style_rounded,
                accentColor: colors.primary,
                colors: colors,
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiMetricCard(
                title: 'Study Velocity',
                value: studyVelocityValue,
                subtitle: studyVelocitySubtitle,
                badgeText: hasStudyTime ? 'On Track' : 'Idle',
                icon: Icons.timer_rounded,
                accentColor: colors.syllabotAccent,
                colors: colors,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiMetricCard(
                title: 'Study Streak',
                value: '${analytics.currentStreakDays} Days 🔥',
                subtitle: hasStreak
                    ? 'Record: ${analytics.longestStreakDays} days'
                    : 'Start a streak today',
                badgeText: analytics.academicRank.isNotEmpty
                    ? analytics.academicRank.split(' ').last
                    : 'Rank I',
                icon: Icons.local_fire_department_rounded,
                accentColor: colors.warning,
                colors: colors,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class KpiMetricCard extends StatelessWidget {
  const KpiMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeText,
    required this.icon,
    required this.accentColor,
    required this.colors,
    required this.isDark,
    super.key,
  });

  final String title;
  final String value;
  final String subtitle;
  final String badgeText;
  final IconData icon;
  final Color accentColor;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? (isHovered
                          ? colors.surfaceSecondary.withAlpha(200)
                          : colors.surfaceSecondary.withAlpha(160))
                    : (isHovered
                          ? colors.surfacePrimary
                          : colors.surfacePrimary.withAlpha(220)),
                borderRadius: BorderRadius.circular(AppRadius.panel),
                border: Border.all(
                  color: isHovered
                      ? accentColor.withAlpha(isDark ? 140 : 100)
                      : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder.withAlpha(130)),
                  width: 1.1,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 50 : 15),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 30 : 8),
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(isDark ? 45 : 25),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                        ),
                        child: Icon(icon, size: 15, color: accentColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withAlpha(isDark ? 35 : 18),
                          borderRadius: BorderRadius.circular(AppRadius.micro),
                          border: Border.all(
                            color: accentColor.withAlpha(isDark ? 70 : 35),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: typography.footnote.bold.copyWith(
                            color: accentColor,
                            fontSize: 9.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: typography.footnote.medium.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 19,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: typography.footnote.regular.copyWith(
                      color: colors.textSecondary.withAlpha(180),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
