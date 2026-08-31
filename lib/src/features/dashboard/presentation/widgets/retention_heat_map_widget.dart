import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class RetentionHeatMapWidget extends StatelessWidget {
  const RetentionHeatMapWidget({
    required this.analytics,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final overallRetention = (analytics.overallRetentionRate * 100).toInt();

    return Semantics(
      container: true,
      label: 'Study Retention Analytics. $overallRetention percent retention.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(160)
                  : colors.surfacePrimary.withAlpha(215),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(70)
                    : colors.surfaceBorder.withAlpha(140),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Detailed Analytics link
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Retention & Study Matrix',
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.lightImpact());
                        unawaited(
                          context.router.push(const AnalyticsDetailRoute()),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            'Full Stats',
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Heat Map Matrix (4 rows of 7 days = 28 days)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = ((constraints.maxWidth - (6 * 6)) / 7)
                        .clamp(14.0, 38.0);

                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: analytics.heatMapData.map((day) {
                        final color = _getIntensityColor(
                          day.intensityLevel,
                          colors,
                          isDark,
                        );

                        return Semantics(
                          label:
                              '${day.date.day}/${day.date.month}: ${day.cardsReviewed} cards',
                          child: Container(
                            width: cellWidth,
                            height: cellWidth,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: day.intensityLevel > 0
                                    ? colors.primary.withAlpha(isDark ? 80 : 40)
                                    : Colors.transparent,
                                width: 0.8,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // 3 Metrics Chips Row
                Row(
                  children: [
                    Expanded(
                      child: _MetricChip(
                        label: 'Retention',
                        value: '$overallRetention%',
                        icon: Icons.psychology_rounded,
                        color: const Color(0xFF10B981),
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricChip(
                        label: 'Mastered',
                        value: '${analytics.totalCardsMastered}',
                        icon: Icons.check_circle_outline_rounded,
                        color: colors.primary,
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricChip(
                        label: 'Study Time',
                        value: '${analytics.weeklyMinutesStudied}m',
                        icon: Icons.schedule_rounded,
                        color: const Color(0xFF8B5CF6),
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getIntensityColor(
    int level,
    AppThemeColorsExtension colors,
    bool isDark,
  ) {
    switch (level) {
      case 0:
        return isDark
            ? colors.surfaceBorderHighlight.withAlpha(30)
            : colors.surfaceBorder.withAlpha(60);
      case 1:
        return colors.primary.withAlpha(isDark ? 60 : 45);
      case 2:
        return colors.primary.withAlpha(isDark ? 120 : 90);
      case 3:
        return colors.primary.withAlpha(isDark ? 190 : 160);
      case 4:
      default:
        return colors.primary;
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.colors,
    required this.isDark,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final AppThemeColorsExtension colors;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfacePrimary.withAlpha(120)
            : colors.surfaceSecondary.withAlpha(140),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(100),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: typography.footnote.regular.copyWith(
                  color: colors.textMuted,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: typography.callout.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
