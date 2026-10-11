import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';

/// Detailed 28-Day Consistency Matrix with Day Inspector.
class AnalyticsDetailedHeatMapCard extends StatefulWidget {
  const AnalyticsDetailedHeatMapCard({
    required this.analytics,
    required this.colors,
    required this.isDark,
    this.timeframeIndex = 0,
    super.key,
  });

  final AnalyticsSummaryEntity analytics;
  final AppThemeColorsExtension colors;
  final bool isDark;
  final int timeframeIndex;

  @override
  State<AnalyticsDetailedHeatMapCard> createState() =>
      _AnalyticsDetailedHeatMapCardState();
}

class _AnalyticsDetailedHeatMapCardState
    extends State<AnalyticsDetailedHeatMapCard> {
  HeatMapDayEntity? _selectedDay;

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _dateKey(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  List<HeatMapDayEntity> _getNormalizedDays(
    List<HeatMapDayEntity> input,
    int timeframeIndex,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dataMap = <String, HeatMapDayEntity>{};
    for (final item in input) {
      dataMap[_dateKey(item.date)] = item;
    }

    // timeframeIndex == 0: 1 week (7 days); otherwise 4 weeks (28 days)
    final weeks = timeframeIndex == 0 ? 1 : 4;
    final currentMonday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    final startMonday = DateTime(
      currentMonday.year,
      currentMonday.month,
      currentMonday.day - ((weeks - 1) * 7),
    );

    final totalDays = weeks * 7;
    return List.generate(totalDays, (i) {
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
  void didUpdateWidget(AnalyticsDetailedHeatMapCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeframeIndex != widget.timeframeIndex) {
      _selectedDay = null;
    } else if (_selectedDay != null) {
      final normalized = _getNormalizedDays(
        widget.analytics.heatMapData,
        widget.timeframeIndex,
      );
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
    final colors = widget.colors;
    final typography = context.typography;
    final isDark = widget.isDark;
    const weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final normalizedDays = _getNormalizedDays(
      widget.analytics.heatMapData,
      widget.timeframeIndex,
    );
    final hasActivity = normalizedDays.any(
      (d) => d.cardsReviewed > 0 || d.minutesStudied > 0,
    );

    final String statusLabel;
    if (widget.timeframeIndex == 0) {
      statusLabel = hasActivity ? 'Active Week' : 'Last 7 Days';
    } else if (widget.timeframeIndex == 1) {
      statusLabel = hasActivity ? 'Active Month' : 'Past 30 Days';
    } else {
      statusLabel = hasActivity ? 'Active Habit' : 'All-Time Grid';
    }

    final rowCount = (normalizedDays.length / 7).ceil();

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(160)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: BorderRadius.circular(AppRadius.panel),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder.withAlpha(140),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Study Consistency Grid',
                        style: typography.title3.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    statusLabel,
                    style: typography.caption.bold.copyWith(
                      color: hasActivity
                          ? colors.success
                          : colors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Weekday Headers & Heat Map Matrix
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = ((constraints.maxWidth - (6 * 6)) / 7)
                      .clamp(16.0, 42.0);

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
                                fontSize: 9.5,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),

                      // Rows of 7 days strictly aligned Monday to Sunday
                      ...List.generate(rowCount, (rowIdx) {
                        final startIdx = rowIdx * 7;
                        final rowDays = normalizedDays.sublist(
                          startIdx,
                          math.min(startIdx + 7, normalizedDays.length),
                        );

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: rowIdx < rowCount - 1 ? 6.0 : 0.0,
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

                              return InkWell(
                                onTap: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  setState(() {
                                    _selectedDay = isSelected ? null : day;
                                  });
                                },
                                borderRadius: BorderRadius.circular(
                                  AppRadius.micro,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
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
                              );
                            }).toList(),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Selected Day Inspector Tooltip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
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
                      Flexible(
                        child: Text(
                          DateFormat('EEEE, MMM d').format(_selectedDay!.date),
                          style: typography.footnote.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 11.5,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_selectedDay!.cardsReviewed} cards reviewed • '
                          '${_selectedDay!.minutesStudied}m studied',
                          style: typography.footnote.medium.copyWith(
                            color: colors.primary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: Text(
                          hasActivity
                              ? 'Tap any day to inspect study performance'
                              : 'No study activity in past 28 days',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Less',
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
                            'More',
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
            ],
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
