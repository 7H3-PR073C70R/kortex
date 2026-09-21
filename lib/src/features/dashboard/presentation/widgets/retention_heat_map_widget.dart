import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class RetentionHeatMapWidget extends StatefulWidget {
  const RetentionHeatMapWidget({
    required this.analytics,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;

  @override
  State<RetentionHeatMapWidget> createState() => _RetentionHeatMapWidgetState();
}

class _RetentionHeatMapWidgetState extends State<RetentionHeatMapWidget> {
  HeatMapDayEntity? _selectedDay;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<HeatMapDayEntity> _getNormalized28Days(List<HeatMapDayEntity> input) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataMap = <String, HeatMapDayEntity>{};
    for (final item in input) {
      dataMap[_dateKey(item.date)] = item;
    }

    // Weekday in Dart: 1 = Monday, 7 = Sunday
    final currentMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    // 4 weeks starting on Monday 3 weeks ago (21 days prior)
    final startMonday = DateTime(
      currentMonday.year,
      currentMonday.month,
      currentMonday.day - 21,
    );

    return List.generate(28, (i) {
      final cellDate = DateTime(
        startMonday.year,
        startMonday.month,
        startMonday.day + i,
      );
      final key = _dateKey(cellDate);
      final existing = dataMap[key];
      if (existing != null) {
        return existing;
      }
      return HeatMapDayEntity(
        date: cellDate,
        intensityLevel: 0,
        cardsReviewed: 0,
        minutesStudied: 0,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final normalized = _getNormalized28Days(widget.analytics.heatMapData);
    final todayMatch = normalized
        .where((d) => _isSameDay(d.date, now))
        .firstOrNull;
    _selectedDay = todayMatch ?? normalized.lastOrNull;
  }

  @override
  void didUpdateWidget(RetentionHeatMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedDay != null) {
      final normalized = _getNormalized28Days(widget.analytics.heatMapData);
      final match = normalized
          .where((d) => _isSameDay(d.date, _selectedDay!.date))
          .firstOrNull;
      if (match != null) {
        _selectedDay = match;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final overallRetention = (widget.analytics.overallRetentionRate * 100)
        .toInt();

    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final normalizedDays = _getNormalized28Days(widget.analytics.heatMapData);

    return Semantics(
      container: true,
      label:
          '${l10n.dashboardRetentionMatrix}. '
          '${l10n.dashboardRetentionChip}: $overallRetention%. '
          '${l10n.dashboardMasteredChip}: '
          '${widget.analytics.totalCardsMastered}.',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.panel),
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(160)
                  : colors.surfacePrimary.withAlpha(215),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 60 : 35),
              ),
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
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(
                              AppRadius.badge,
                            ),
                          ),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 15,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.dashboardRetentionMatrix,
                              style: typography.title3.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              l10n.dashboardHeatmapSubtitle,
                              style: typography.footnote.medium.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
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
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 40 : 20),
                          borderRadius: BorderRadius.circular(AppRadius.badge),
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 80 : 40),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.dashboardFullStats,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Weekday Headers & 4-Week Heat Map Matrix
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellWidth = ((constraints.maxWidth - (6 * 6)) / 7)
                        .clamp(14.0, 38.0);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Weekday labels (Mon..Sun)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: weekdayLabels.map((day) {
                            return SizedBox(
                              width: cellWidth,
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: typography.footnote.bold.copyWith(
                                  color: colors.textSecondary.withAlpha(160),
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 6),

                        // Heat Map Matrix: exactly 4 rows of 7 days (Monday..Sunday)
                        ...List.generate(4, (rowIdx) {
                          final startIdx = rowIdx * 7;
                          final rowDays = normalizedDays.sublist(
                            startIdx,
                            startIdx + 7,
                          );

                          return Padding(
                            padding: EdgeInsets.only(
                              bottom: rowIdx < 3 ? 6.0 : 0.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: rowDays.map((day) {
                                final isSelected =
                                    _selectedDay != null &&
                                    _isSameDay(_selectedDay!.date, day.date);
                                final color = _getIntensityColor(
                                  day.intensityLevel,
                                  colors,
                                  isDark,
                                );

                                return Semantics(
                                  label:
                                      '${day.date.day}/${day.date.month}: '
                                      '${day.cardsReviewed} cards',
                                  child: InkWell(
                                    onTap: () {
                                      unawaited(
                                        HapticFeedback.selectionClick(),
                                      );
                                      setState(() {
                                        _selectedDay = isSelected ? null : day;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.micro,
                                    ),
                                    child: AnimatedContainer(
                                      duration: AppMotion.snappy,
                                      curve: AppMotion.easeOutCubic,
                                      width: cellWidth,
                                      height: cellWidth,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.micro,
                                        ),
                                        border: Border.all(
                                          color: isSelected
                                              ? colors.textPrimary
                                              : (day.intensityLevel > 0
                                                    ? colors.primary.withAlpha(
                                                        isDark ? 90 : 50,
                                                      )
                                                    : colors.transparent),
                                          width: isSelected ? 1.8 : 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Selected Day Inspector Tooltip / Summary Banner
                AnimatedContainer(
                  duration: AppMotion.standard,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedDay != null
                        ? colors.primary.withAlpha(isDark ? 35 : 15)
                        : (isDark
                              ? colors.surfacePrimary.withAlpha(80)
                              : colors.surfaceSecondary.withAlpha(90)),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: _selectedDay != null
                          ? colors.primary.withAlpha(isDark ? 80 : 40)
                          : colors.surfaceBorder.withAlpha(isDark ? 40 : 80),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_selectedDay != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              size: 12,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              DateFormat('EEE, MMM d').format(
                                _selectedDay!.date,
                              ),
                              style: typography.footnote.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_selectedDay!.cardsReviewed} cards • '
                          '${_selectedDay!.minutesStudied} mins',
                          style: typography.footnote.medium.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Text(
                          l10n.dashboardHeatmapTapHint,
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        // Intensity scale indicator
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.dashboardHeatmapLess,
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary.withAlpha(160),
                                fontSize: 9.5,
                              ),
                            ),
                            const SizedBox(width: 4),
                            ...List.generate(5, (lvl) {
                              return Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: _getIntensityColor(
                                    lvl,
                                    colors,
                                    isDark,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                            const SizedBox(width: 4),
                            Text(
                              l10n.dashboardHeatmapMore,
                              style: typography.footnote.regular.copyWith(
                                color: colors.textSecondary.withAlpha(160),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 3 Metrics Chips Row
                Row(
                  children: [
                    Expanded(
                      child: _MetricChip(
                        label: l10n.dashboardRetentionChip,
                        value: '$overallRetention%',
                        icon: Icons.psychology_rounded,
                        color: colors.success,
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricChip(
                        label: l10n.dashboardMasteredChip,
                        value: '${widget.analytics.totalCardsMastered}',
                        icon: Icons.check_circle_outline_rounded,
                        color: colors.primary,
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricChip(
                        label: l10n.dashboardStudyTimeChip,
                        value: l10n.dashboardStudyTimeMinutes(
                          widget.analytics.weeklyMinutesStudied,
                        ),
                        icon: Icons.schedule_rounded,
                        color: colors.syllabotAccent,
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
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 50 : 25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.footnote.medium.copyWith(
                    color: isDark
                        ? colors.textSecondary
                        : colors.textPrimary.withAlpha(180),
                    fontSize: 10.5,
                  ),
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
