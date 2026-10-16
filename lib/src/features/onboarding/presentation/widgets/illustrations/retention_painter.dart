// CustomPainters draw sequential canvas calls; cascading hurts readability.
// ignore_for_file: cascade_invocations
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/illustration_common.dart';

/// 3. RETENTION — the forgetting curve held up by timed reviews
class RetentionPainter extends CustomPainter {
  RetentionPainter(this.t, this.c);

  final double t;
  final AppThemeColorsExtension c;

  // Review resets happen at these normalized x positions.
  static const List<double> _reviews = [0.34, 0.67];

  /// Retention (0..1) at normalized time x: exponential decay within each
  /// cycle, snapping back toward 1.0 at every review. Each cycle's floor is
  /// higher than the last — memories become harder to forget.
  double _retentionAt(double x) {
    final cycles = [
      (start: 0.0, end: 0.34, low: 0.44),
      (start: 0.34, end: 0.67, low: 0.60),
      (start: 0.67, end: 1.0, low: 0.78),
    ];
    for (final cy in cycles) {
      if (x < cy.end || cy == cycles.last) {
        final u = ((x - cy.start) / (cy.end - cy.start)).clamp(0.0, 1.0);
        return cy.low + (1.0 - cy.low) * math.exp(-2.8 * u);
      }
    }
    return 1;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final left = w * 0.14;
    final right = w * 0.92;
    final top = h * 0.16;
    final bottom = h * 0.78;

    Offset mapXY(double x, double r) =>
        Offset(left + x * (right - left), bottom - r * (bottom - top));

    // Axes.
    final axis = Paint()
      ..color = c.textMuted.withAlpha(120)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(left, top), Offset(left, bottom), axis);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), axis);
    drawLabel(
      canvas,
      'Retention',
      at: Offset(left, top - 18),
      size: 11,
      color: c.textSecondary,
    );
    drawLabel(
      canvas,
      'Time →',
      at: Offset(right - 40, bottom + 8),
      size: 11,
      color: c.textSecondary,
    );

    // Reveal the curve left → right.
    final p = seg(t, 0.08, 0.92);
    const steps = 60;
    final curve = Path();
    final area = Path();
    for (var i = 0; i <= steps; i++) {
      final x = (i / steps) * p;
      final o = mapXY(x, _retentionAt(x));
      if (i == 0) {
        curve.moveTo(o.dx, o.dy);
        area.moveTo(o.dx, bottom);
        area.lineTo(o.dx, o.dy);
      } else {
        curve.lineTo(o.dx, o.dy);
        area.lineTo(o.dx, o.dy);
      }
    }
    area
      ..lineTo(mapXY(p, 0).dx, bottom)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [c.success.withAlpha(70), c.success.withAlpha(0)],
        ),
    );
    canvas.drawPath(
      curve,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = c.success,
    );

    // Review markers: a vertical tick + a pulse when the leading edge hits it.
    for (final rx in _reviews) {
      final base = mapXY(rx, 0);
      final peak = mapXY(rx, _retentionAt(rx));
      canvas.drawLine(
        base,
        Offset(base.dx, top),
        Paint()
          ..color = c.info.withAlpha(70)
          ..strokeWidth = 1.2,
      );
      final hit = (p - rx).abs() < 0.03 && p > 0;
      final r = hit ? 6.0 + math.sin(t * 40) * 2 : 5.0;
      canvas.drawCircle(
        Offset(peak.dx, peak.dy),
        r,
        Paint()..color = c.info.withAlpha(hit ? 255 : 180),
      );
      canvas.drawCircle(
        Offset(peak.dx, peak.dy),
        r + 3,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = c.info.withAlpha(hit ? 160 : 60),
      );
      drawLabel(
        canvas,
        'review',
        at: Offset(peak.dx - 18, top - 16),
        size: 9,
        color: c.info,
      );
    }

    // Leading dot.
    if (p > 0 && p < 1) {
      final head = mapXY(p, _retentionAt(p));
      canvas.drawCircle(head, 4, Paint()..color = c.white);
      canvas.drawCircle(
        head,
        7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = c.success.withAlpha(160),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RetentionPainter old) => old.t != t;
}
