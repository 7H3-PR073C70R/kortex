import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_trend_calculator.dart';

/// Interactive glassmorphic Weekly CBT Readiness Trend Chart widget displaying
/// empirical score trajectory across 6 rolling weekly periods.
class CbtReadinessWeeklyTrendsChart extends StatefulWidget {
  const CbtReadinessWeeklyTrendsChart({
    required this.currentReadinessScore,
    this.sessions = const [],
    this.targetTrack,
    this.weekCount = 6,
    super.key,
  });

  final double currentReadinessScore;
  final List<Map<String, dynamic>> sessions;
  final String? targetTrack;
  final int weekCount;

  @override
  State<CbtReadinessWeeklyTrendsChart> createState() =>
      _CbtReadinessWeeklyTrendsChartState();
}

class _CbtReadinessWeeklyTrendsChartState
    extends State<CbtReadinessWeeklyTrendsChart> {
  int? _selectedWeekIndex;
  late List<CbtReadinessTrendPoint> _trendPoints;

  @override
  void initState() {
    super.initState();
    _recalculatePoints();
    _selectedWeekIndex = _trendPoints.isNotEmpty ? _trendPoints.length - 1 : null;
  }

  @override
  void didUpdateWidget(CbtReadinessWeeklyTrendsChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentReadinessScore != widget.currentReadinessScore ||
        oldWidget.sessions.length != widget.sessions.length) {
      _recalculatePoints();
    }
  }

  void _recalculatePoints() {
    const calculator = CbtReadinessTrendCalculator();
    _trendPoints = calculator.calculateWeeklyTrend(
      sessions: widget.sessions,
      currentReadinessScore: widget.currentReadinessScore,
      weekCount: widget.weekCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedPoint = (_selectedWeekIndex != null &&
            _selectedWeekIndex! < _trendPoints.length)
        ? _trendPoints[_selectedWeekIndex!]
        : (_trendPoints.isNotEmpty ? _trendPoints.last : null);

    // Compute progress delta since first calibrated week
    final firstCalibrated =
        _trendPoints.where((p) => p.readinessScore > 0).firstOrNull;
    final double scoreDelta;
    if (firstCalibrated != null && widget.currentReadinessScore > 0) {
      scoreDelta = widget.currentReadinessScore - firstCalibrated.readinessScore;
    } else {
      scoreDelta = 0.0;
    }

    final hasPositiveGain = scoreDelta >= 0;
    final gainColor = widget.currentReadinessScore >= 70
        ? colors.success
        : (widget.currentReadinessScore >= 50 ? colors.warning : colors.primary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary.withAlpha(220),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 90 : 130),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEKLY READINESS TREND',
                    style: typography.caption.bold.copyWith(
                      color: colors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.currentReadinessScore.round()}% Current Index',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (firstCalibrated != null && scoreDelta != 0.0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (hasPositiveGain ? colors.success : colors.error)
                        .withAlpha(25),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                    border: Border.all(
                      color: (hasPositiveGain ? colors.success : colors.error)
                          .withAlpha(100),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasPositiveGain
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        size: 15,
                        color: hasPositiveGain ? colors.success : colors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${hasPositiveGain ? '+' : ''}${scoreDelta.round()}%',
                        style: typography.caption.bold.copyWith(
                          color: hasPositiveGain ? colors.success : colors.error,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Custom Painter Chart
          SizedBox(
            height: 130,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    final width = constraints.maxWidth;
                    if (_trendPoints.isEmpty || width <= 0) return;
                    final stepX = width / math.max(1, _trendPoints.length - 1);
                    final tappedIndex =
                        (details.localPosition.dx / stepX).round().clamp(
                              0,
                              _trendPoints.length - 1,
                            );
                    AppFeedback.selection();
                    setState(() {
                      _selectedWeekIndex = tappedIndex;
                    });
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 130),
                    painter: _TrendCurvePainter(
                      points: _trendPoints,
                      selectedIndex: _selectedWeekIndex,
                      lineColor: gainColor,
                      benchmarkScore: 70,
                      isDark: isDark,
                      colors: colors,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // X-Axis Week Labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _trendPoints.map((p) {
              final isSelected = p.weekIndex == _selectedWeekIndex;
              return GestureDetector(
                onTap: () {
                  AppFeedback.selection();
                  setState(() => _selectedWeekIndex = p.weekIndex);
                },
                child: Text(
                  p.weekLabel,
                  style: typography.caption.semiBold.copyWith(
                    color: isSelected ? gainColor : colors.textMuted,
                    fontSize: 10.5,
                  ),
                ),
              );
            }).toList(),
          ),

          // Selected Point Details Card
          if (selectedPoint != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surfacePrimary.withAlpha(120),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: colors.surfaceBorder.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.insights_rounded,
                    size: 16,
                    color: gainColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedPoint.weekLabel}: ${selectedPoint.readinessScore.round()}% Readiness',
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    selectedPoint.testsCompleted > 0
                        ? '${selectedPoint.testsCompleted} test${selectedPoint.testsCompleted > 1 ? 's' : ''} logged'
                        : (selectedPoint.readinessScore > 0 ? 'Projected' : 'Uncalibrated'),
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendCurvePainter extends CustomPainter {
  _TrendCurvePainter({
    required this.points,
    required this.selectedIndex,
    required this.lineColor,
    required this.benchmarkScore,
    required this.isDark,
    required this.colors,
  });

  final List<CbtReadinessTrendPoint> points;
  final int? selectedIndex;
  final Color lineColor;
  final double benchmarkScore;
  final bool isDark;
  final AppThemeColorsExtension colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final w = size.width;
    final h = size.height;

    // Draw 70% Benchmark Target Dashed Line
    final benchmarkY = h - (benchmarkScore / 100.0 * (h - 20) + 10);
    final dashPaint = Paint()
      ..color = colors.textMuted.withAlpha(50)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    var startX = 0.0;
    while (startX < w) {
      canvas.drawLine(
        Offset(startX, benchmarkY),
        Offset(math.min(startX + dashWidth, w), benchmarkY),
        dashPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Compute pixel coordinates for each point
    final coords = <Offset>[];
    final stepX = w / math.max(1, points.length - 1);

    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      // Normalizing score 0-100 to vertical area with 10px padding top and bottom
      final normalizedScore = (points[i].readinessScore / 100.0).clamp(0.0, 1.0);
      final y = h - (normalizedScore * (h - 24) + 12);
      coords.add(Offset(x, y));
    }

    // Smooth Bezier Curve Path
    final path = Path()..moveTo(coords[0].dx, coords[0].dy);

    for (var i = 0; i < coords.length - 1; i++) {
      final p0 = coords[i];
      final p1 = coords[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    // Gradient Area Fill under the path
    final fillPath = Path.from(path)
      ..lineTo(coords.last.dx, h)
      ..lineTo(coords.first.dx, h)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withAlpha(isDark ? 55 : 35),
          lineColor.withAlpha(0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Main Stroke Curve
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, strokePaint);

    // Nodes
    final nodeFillPaint = Paint()..color = colors.surfacePrimary;
    final nodeBorderPaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final selectedNodePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (var i = 0; i < coords.length; i++) {
      final c = coords[i];
      final isSelected = i == selectedIndex;

      if (isSelected) {
        // Outer pulsing ring
        canvas
          ..drawCircle(
            c,
            7.5,
            Paint()..color = lineColor.withAlpha(70),
          )
          ..drawCircle(c, 4.5, selectedNodePaint);
      } else {
        canvas
          ..drawCircle(c, 3.5, nodeFillPaint)
          ..drawCircle(c, 3.5, nodeBorderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_TrendCurvePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.isDark != isDark;
  }
}
