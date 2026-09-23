import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
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

  /// Cell fill/border per Tailwind intensity level in the design.
  ({Color fill, Color border, bool glow}) _cellStyle(int level) {
    final neural = context.neural;
    return switch (level) {
      <= 0 => (
        fill: neural.obsidian800.withAlpha(230),
        border: neural.hairlineSoft,
        glow: false,
      ),
      1 => (
        fill: neural.emerald.withAlpha(51),
        border: neural.emerald.withAlpha(77),
        glow: false,
      ),
      2 => (
        fill: neural.emerald.withAlpha(77),
        border: neural.emerald.withAlpha(77),
        glow: false,
      ),
      3 => (
        fill: neural.emerald.withAlpha(102),
        border: neural.emerald.withAlpha(102),
        glow: false,
      ),
      _ => (
        fill: neural.emerald.withAlpha(153),
        border: neural.emerald400,
        glow: true,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

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
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: neural.glassPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: neural.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: icon box + title + Full Stats button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: neural.obsidian800,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: neural.hairlineStrong,
                              ),
                            ),
                            child: Icon(
                              Icons.grid_view_rounded,
                              size: 16,
                              color: neural.emerald400,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.dashboardRetentionMatrix,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.callout.bold.copyWith(
                                    color: neural.slate100,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  l10n.dashboardHeatmapSubtitle,
                                  style: typography.caption.regular.copyWith(
                                    color: neural.slate400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: neural.obsidian800.withAlpha(204),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: neural.hairlineSoft,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.dashboardFullStats,
                              style: typography.caption.medium.copyWith(
                                color: neural.slate300,
                                fontSize: 12,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 12,
                              color: neural.slate400,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Heatmap matrix container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: neural.obsidian900.withAlpha(230),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neural.hairlineSoft),
                  ),
                  child: Column(
                    children: [
                      // Weekday labels (Mon..Sun)
                      Row(
                        children: [
                          for (final label in weekdayLabels)
                            Expanded(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: typography.footnote.bold.copyWith(
                                  color: neural.slate400,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 4 rows x 7 days with gap-1.5 (6px)
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
                            children: [
                              for (var colIdx = 0; colIdx < 7; colIdx++)
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: colIdx < 6 ? 6.0 : 0.0,
                                    ),
                                    child:
                                        _HeatMapCell(
                                              day: rowDays[colIdx],
                                              isSelected:
                                                  _selectedDay != null &&
                                                  _isSameDay(
                                                    _selectedDay!.date,
                                                    rowDays[colIdx].date,
                                                  ),
                                              style: _cellStyle(
                                                rowDays[colIdx].intensityLevel,
                                              ),
                                              onTap: () {
                                                unawaited(
                                                  HapticFeedback.selectionClick(),
                                                );
                                                setState(() {
                                                  _selectedDay =
                                                      _selectedDay != null &&
                                                          _isSameDay(
                                                            _selectedDay!.date,
                                                            rowDays[colIdx]
                                                                .date,
                                                          )
                                                      ? null
                                                      : rowDays[colIdx];
                                                });
                                              },
                                            )
                                            .animate(
                                              delay: (rowIdx * 30 + colIdx * 30)
                                                  .ms,
                                            )
                                            .fadeIn(duration: 350.ms)
                                            .scaleXY(
                                              begin: 0.6,
                                              end: 1,
                                              curve: Curves.easeOutCubic,
                                            ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Selected date inspector with KPI breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: neural.obsidian900.withAlpha(242),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: neural.hairlineStrong),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: neural.hairlineSoft,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 14,
                                    color: _selectedDay != null
                                        ? neural.emerald400
                                        : neural.slate400,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _selectedDay != null
                                          ? DateFormat(
                                              'EEE, MMM d',
                                            ).format(_selectedDay!.date)
                                          : l10n.dashboardHeatmapTapHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: typography.caption.semiBold
                                          .copyWith(
                                            color: neural.slate300,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _selectedDay != null
                                  ? '${_selectedDay!.cardsReviewed} cards • '
                                        '${_selectedDay!.minutesStudied} mins'
                                  : l10n.dashboardHeatmapSubtitle,
                              style: typography.code.regular.copyWith(
                                color: neural.slate400,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children:
                            <Widget>[
                                  Expanded(
                                    child: _InspectorTile(
                                      icon: Icons.psychology_rounded,
                                      iconColor: neural.pink400,
                                      label: l10n.dashboardRetentionChip,
                                      value: '$overallRetention%',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _InspectorTile(
                                      icon: Icons.check_circle_outline_rounded,
                                      iconColor: neural.emerald400,
                                      label: l10n.dashboardMasteredChip,
                                      value:
                                          '${widget.analytics.totalCardsMastered}',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _InspectorTile(
                                      icon: Icons.schedule_rounded,
                                      iconColor: neural.amber400,
                                      label: l10n.dashboardStudyTimeChip,
                                      value: l10n.dashboardStudyTimeMinutes(
                                        widget.analytics.weeklyMinutesStudied,
                                      ),
                                    ),
                                  ),
                                ]
                                .animate(interval: 50.ms, delay: 200.ms)
                                .fadeIn(duration: 350.ms)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  curve: Curves.easeOutCubic,
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeatMapCell extends StatelessWidget {
  const _HeatMapCell({
    required this.day,
    required this.isSelected,
    required this.style,
    required this.onTap,
  });

  final HeatMapDayEntity day;
  final bool isSelected;
  final ({Color fill, Color border, bool glow}) style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;

    return Semantics(
      label: '${day.date.day}/${day.date.month}: ${day.cardsReviewed} cards',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: AspectRatio(
          aspectRatio: 1,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? neural.obsidian700.withAlpha(204)
                  : style.fill,
              borderRadius: BorderRadius.circular(6),
              border: isSelected
                  ? Border.all(color: neural.slate100, width: 2)
                  : Border.all(color: style.border),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    // ring-2 ring-emerald-500/50 approximation
                    color: neural.emerald.withAlpha(128),
                    spreadRadius: 1,
                  )
                else if (style.glow)
                  BoxShadow(
                    color: neural.glowMatrixActive,
                    blurRadius: 10,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectorTile extends StatelessWidget {
  const _InspectorTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: neural.obsidian850,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: neural.hairlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.regular.copyWith(
                    color: neural.slate400,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.code.bold.copyWith(
              color: neural.slate100,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
