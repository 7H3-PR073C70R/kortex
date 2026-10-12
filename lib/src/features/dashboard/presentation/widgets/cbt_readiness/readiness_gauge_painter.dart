import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Custom painter for rendering the circular CBT Readiness progress arc.
class ReadinessGaugePainter extends CustomPainter {
  const ReadinessGaugePainter({
    required this.scorePercent,
    required this.color,
    required this.trackColor,
  });

  final int scorePercent;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 12) / 2;
    const strokeWidth = 10.0;
    const startAngle = 0.75 * math.pi;
    const totalSweep = 1.5 * math.pi;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    final sweepAngle = totalSweep * (scorePercent / 100.0);
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        valuePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ReadinessGaugePainter oldDelegate) {
    return oldDelegate.scorePercent != scorePercent ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Horizontal metric progress bar used alongside the readiness gauge.
class ReadinessMetricBar extends StatelessWidget {
  const ReadinessMetricBar({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final percent = (value.clamp(0.0, 1.0) * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: typography.caption.medium.copyWith(
                color: colors.textSecondary,
              ),
            ),
            Text(
              '$percent%',
              style: typography.caption.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.micro),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colors.surfaceBorder.withAlpha(60),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
