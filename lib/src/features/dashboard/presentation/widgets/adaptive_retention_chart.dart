import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';
import 'package:kortex/src/l10n/l10n.dart';

class AdaptiveRetentionChart extends StatefulWidget {
  const AdaptiveRetentionChart({
    required this.points,
    super.key,
  });

  final List<DailyRetentionPoint> points;

  @override
  State<AdaptiveRetentionChart> createState() => _AdaptiveRetentionChartState();
}

class _AdaptiveRetentionChartState extends State<AdaptiveRetentionChart> {
  int? _selectedDayIndex;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final selectedPoint = _selectedDayIndex != null &&
            _selectedDayIndex! < widget.points.length
        ? widget.points[_selectedDayIndex!]
        : widget.points.isNotEmpty
            ? widget.points.first
            : null;

    final pointRetention = selectedPoint != null
        ? (selectedPoint.predictedRetention * 100).toInt()
        : 0;
    final pointDay = selectedPoint?.day ?? 1;
    final pointDue = selectedPoint?.dueCardsCount ?? 0;

    return Semantics(
      container: true,
      label: 'Adaptive Memory Retention Chart rendering 7-day predicted and '
          'actual recall curves',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(160)
                  : colors.surfacePrimary.withAlpha(220),
              borderRadius: BorderRadius.circular(22),
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
                // Chart Header & Metric Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.show_chart_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  l10n.projectedWorkloadTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.title3.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (selectedPoint != null)
                            Text(
                              'Day $pointDay: $pointRetention% '
                              'Retention • $pointDue Due Cards',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Legend
                    Row(
                      children: [
                        _LegendChip(
                          color: colors.primary,
                          label: 'Predicted',
                          colors: colors,
                        ),
                        const SizedBox(width: 10),
                        _LegendChip(
                          color: colors.success,
                          label: 'Actual',
                          colors: colors,
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Interactive Curve Canvas
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: GestureDetector(
                    onPanDown: (details) =>
                        _updateSelection(details.localPosition),
                    onPanUpdate: (details) =>
                        _updateSelection(details.localPosition),
                    child: CustomPaint(
                      painter: _RetentionChartPainter(
                        points: widget.points,
                        predictedColor: colors.primary,
                        actualColor: colors.success,
                        gridColor: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(40)
                            : colors.surfaceBorder.withAlpha(120),
                        selectedDay: _selectedDayIndex,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Day Labels Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    widget.points.length,
                    (index) => Semantics(
                      button: true,
                      label: 'Day ${widget.points[index].day} Retention Point',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDayIndex = index;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedDayIndex == index
                                ? colors.primary.withAlpha(isDark ? 50 : 25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedDayIndex == index
                                  ? colors.primary.withAlpha(isDark ? 100 : 60)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            'D${widget.points[index].day}',
                            style: typography.caption.medium.copyWith(
                              color: _selectedDayIndex == index
                                  ? colors.primary
                                  : colors.textSecondary,
                              fontWeight: _selectedDayIndex == index
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateSelection(Offset localPosition) {
    if (widget.points.isEmpty) return;
    const padding = 20.0;
    final totalWidth = context.size?.width ?? 320.0;
    final chartWidth = totalWidth - (padding * 2);
    final ratio = (localPosition.dx / chartWidth).clamp(0.0, 1.0);
    final index = (ratio * (widget.points.length - 1)).round();
    setState(() {
      _selectedDayIndex = index;
    });
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.color,
    required this.label,
    required this.colors,
  });

  final Color color;
  final String label;
  final AppThemeColorsExtension colors;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: typography.footnote.medium.copyWith(
            fontSize: 11,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RetentionChartPainter extends CustomPainter {
  _RetentionChartPainter({
    required this.points,
    required this.predictedColor,
    required this.actualColor,
    required this.gridColor,
    this.selectedDay,
  });

  final List<DailyRetentionPoint> points;
  final Color predictedColor;
  final Color actualColor;
  final Color gridColor;
  final int? selectedDay;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Draw horizontal gridlines (100%, 75%, 50%)
    for (var i = 1; i <= 3; i++) {
      final y = size.height * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stepX = size.width / (points.length - 1);

    // Predicted Curve Path
    final predictedPath = Path();
    final actualPath = Path();

    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final yPred = size.height * (1.0 - points[i].predictedRetention);
      final yAct = size.height * (1.0 - points[i].actualRetention);

      if (i == 0) {
        predictedPath.moveTo(x, yPred);
        actualPath.moveTo(x, yAct);
      } else {
        predictedPath.lineTo(x, yPred);
        actualPath.lineTo(x, yAct);
      }
    }

    final predStroke = Paint()
      ..color = predictedColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;

    final actStroke = Paint()
      ..color = actualColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawPath(predictedPath, predStroke)
      ..drawPath(actualPath, actStroke);

    // Highlight selected day marker
    if (selectedDay != null && selectedDay! < points.length) {
      final selX = selectedDay! * stepX;
      final selPoint = points[selectedDay!];
      final selY = size.height * (1.0 - selPoint.predictedRetention);

      final markerPaint = Paint()..color = predictedColor;
      canvas
        ..drawCircle(Offset(selX, selY), 6, markerPaint)
        ..drawLine(
          Offset(selX, 0),
          Offset(selX, size.height),
          Paint()
            ..color = predictedColor.withAlpha(80)
            ..strokeWidth = 1.5,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _RetentionChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedDay != selectedDay ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.predictedColor != predictedColor;
  }
}
