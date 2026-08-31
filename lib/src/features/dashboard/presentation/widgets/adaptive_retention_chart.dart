import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
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
    final theme = context.theme;
    final l10n = context.l10n;

    final selectedPoint = _selectedDayIndex != null &&
            _selectedDayIndex! < widget.points.length
        ? widget.points[_selectedDayIndex!]
        : widget.points.isNotEmpty
            ? widget.points.first
            : null;

    return Semantics(
      container: true,
      label: 'Adaptive Memory Retention Chart rendering 7-day predicted and '
          'actual recall curves',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
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
                      Text(
                        l10n.projectedWorkloadTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (selectedPoint != null)
                        Text(
                          'Day ${selectedPoint.day}: '
                          '${(selectedPoint.predictedRetention * 100).toInt()}%'
                          ' Retention • '
                          '${selectedPoint.dueCardsCount} Due Cards',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
                      color: theme.colorScheme.primary,
                      label: 'Predicted',
                    ),
                    const SizedBox(width: 8),
                    const _LegendChip(
                      color: Colors.greenAccent,
                      label: 'Actual',
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
                onPanDown: (details) => _updateSelection(details.localPosition),
                onPanUpdate: (details) =>
                    _updateSelection(details.localPosition),
                child: CustomPaint(
                  painter: _RetentionChartPainter(
                    points: widget.points,
                    predictedColor: theme.colorScheme.primary,
                    actualColor: Colors.greenAccent,
                    selectedDay: _selectedDayIndex,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Text(
                        'D${widget.points[index].day}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _selectedDayIndex == index
                              ? theme.colorScheme.primary
                              : Colors.white60,
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
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
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
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
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
    this.selectedDay,
  });

  final List<DailyRetentionPoint> points;
  final Color predictedColor;
  final Color actualColor;
  final int? selectedDay;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
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
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final actStroke = Paint()
      ..color = actualColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
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
        ..drawCircle(Offset(selX, selY), 5, markerPaint)
        ..drawLine(
          Offset(selX, 0),
          Offset(selX, size.height),
          Paint()
            ..color = predictedColor.withValues(alpha: 0.3)
            ..strokeWidth = 1.5,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _RetentionChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedDay != selectedDay;
  }
}
