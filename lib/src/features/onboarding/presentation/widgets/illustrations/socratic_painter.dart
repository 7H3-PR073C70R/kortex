// CustomPainters draw sequential canvas calls; cascading hurts readability.
// ignore_for_file: cascade_invocations
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/illustration_common.dart';

/// 4. SOCRATIC — a confidence gauge calibrating toward exam-ready
class SocraticPainter extends CustomPainter {
  SocraticPainter(this.t, this.c);

  final double t;
  final AppThemeColorsExtension c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- Socratic hint dots (leads you there, never spills the answer) ---
    final bubble = Rect.fromLTWH(w * 0.10, h * 0.10, w * 0.34, 34);
    canvas.drawRRect(
      rr(bubble, 14),
      Paint()..color = c.surfaceElevated.withAlpha(220),
    );
    canvas.drawRRect(
      rr(bubble, 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = c.warning.withAlpha(150),
    );
    drawLabel(
      canvas,
      '?',
      at: Offset(bubble.left + 12, bubble.top + 8),
      size: 16,
      color: c.warning,
    );
    for (var i = 0; i < 3; i++) {
      final lit = seg(t, 0.20 + i * 0.16, 0.32 + i * 0.16);
      canvas.drawCircle(
        Offset(bubble.left + 34 + i * 14, bubble.center.dy),
        3.4,
        Paint()..color = c.warning.withAlpha((60 + 180 * lit).round()),
      );
    }

    // --- Confidence gauge -------------------------------------------------
    final cx = w * 0.5;
    final cy = h * 0.66;
    final radius = math.min(w * 0.30, h * 0.34);
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Track.
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = c.surfaceBorder.withAlpha(140),
    );

    // Value arc.
    final value = eo(seg(t, 0.10, 0.72)) * 0.94;
    if (value > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.sweep(
          Offset(cx, cy),
          [c.warning, c.success, c.info],
          [0.0, 0.6, 1.0],
          TileMode.clamp,
          math.pi,
        );
      canvas.drawArc(rect, math.pi, math.pi * value, false, arcPaint);

      // Needle.
      final angle = math.pi + math.pi * value;
      canvas.drawLine(
        Offset(cx, cy),
        Offset(
          cx + math.cos(angle) * (radius - 12),
          cy + math.sin(angle) * (radius - 12),
        ),
        Paint()
          ..color = c.textPrimary
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(Offset(cx, cy), 5, Paint()..color = c.textPrimary);
    }

    // Percentage readout, centered on the dial face.
    final pct = (value * 100).round();
    drawLabelCentered(
      canvas,
      '$pct%',
      Offset(cx, cy - 4),
      size: 30,
      color: c.textPrimary,
      weight: FontWeight.w800,
    );
    drawLabelCentered(
      canvas,
      'MASTERY',
      Offset(cx, cy + 18),
      size: 10,
      color: c.textSecondary,
      weight: FontWeight.w700,
    );

    // "Exam-ready" badge as the gauge nears its target.
    final readyP = eo(seg(t, 0.74, 0.9));
    if (readyP > 0) {
      const chipW = 128.0;
      final chip = Rect.fromLTWH(cx - chipW / 2, cy + radius * 0.52, chipW, 26);
      canvas.drawRRect(
        rr(chip, 13),
        Paint()..color = c.success.withAlpha((35 * readyP).round()),
      );
      canvas.drawRRect(
        rr(chip, 13),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = c.success.withAlpha((200 * readyP).round()),
      );
      drawLabelCentered(
        canvas,
        'EXAM-READY',
        Offset(chip.center.dx, chip.center.dy - 6),
        size: 11,
        color: c.success,
        weight: FontWeight.w800,
        opacity: readyP,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SocraticPainter old) => old.t != t;
}
