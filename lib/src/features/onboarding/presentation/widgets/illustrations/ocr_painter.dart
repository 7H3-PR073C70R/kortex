// CustomPainters draw sequential canvas calls; cascading hurts readability.
// ignore_for_file: cascade_invocations
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/illustration_common.dart';

/// 2. STEM OCR — scanner resolves glyphs line by line
class OcrPainter extends CustomPainter {
  OcrPainter(this.t, this.c);

  final double t;
  final AppThemeColorsExtension c;

  static const List<String> _lines = [
    '∫ 2x dx = x²',
    'det(A − λI) = 0',
    'E = mc²',
    'ΔG = ΔH − TΔS',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final sheet = Rect.fromLTWH(w * 0.12, h * 0.14, w * 0.76, h * 0.66);
    canvas.drawRRect(
      rr(sheet, 16),
      Paint()..color = c.surfaceElevated.withAlpha(235),
    );
    canvas.drawRRect(
      rr(sheet, 16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = c.surfaceBorder.withAlpha(160),
    );

    // Reticle corners for the "precision" read frame.
    _corners(canvas, sheet, c.syllabotAccent);

    // Scan travels top -> bottom over the sheet.
    final scanP = seg(t, 0.06, 0.82);
    final scanY = sheet.top + 8 + scanP * (sheet.height - 16);

    final lineTop = sheet.top + sheet.height * 0.20;
    final lineGap = sheet.height * 0.18;
    for (var i = 0; i < _lines.length; i++) {
      final ly = lineTop + i * lineGap;
      final resolved = scanY >= ly;
      if (resolved) {
        drawLabel(
          canvas,
          _lines[i],
          at: Offset(sheet.left + 22, ly - 9),
          size: 15,
          color: c.textPrimary,
          weight: FontWeight.w700,
        );
      } else {
        // Not-yet-read: faint placeholder blocks.
        canvas.drawRRect(
          rr(
            Rect.fromLTWH(sheet.left + 22, ly - 4, sheet.width * 0.52, 8),
            4,
          ),
          Paint()..color = c.textMuted.withAlpha(60),
        );
      }
    }

    // Highlight band riding just above the scan line.
    final band = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, scanY - 22),
        Offset(0, scanY + 2),
        [c.syllabotAccent.withAlpha(0), c.syllabotAccent.withAlpha(60)],
      );
    canvas.save();
    canvas.clipRRect(rr(sheet, 16));
    canvas.drawRect(
      Rect.fromLTWH(sheet.left, scanY - 22, sheet.width, 24),
      band,
    );
    canvas.drawLine(
      Offset(sheet.left + 4, scanY),
      Offset(sheet.right - 4, scanY),
      Paint()
        ..color = c.syllabotAccent
        ..strokeWidth = 2,
    );
    canvas.restore();

    // "LaTeX ✓" confirmation chip once the sweep completes.
    final doneP = eo(seg(t, 0.84, 0.96));
    if (doneP > 0) {
      final chip = Rect.fromLTWH(
        sheet.center.dx - 60,
        sheet.bottom + 10,
        120,
        26,
      );
      canvas.drawRRect(
        rr(chip, 13),
        Paint()..color = c.success.withAlpha((40 * doneP).round()),
      );
      canvas.drawRRect(
        rr(chip, 13),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = c.success.withAlpha((200 * doneP).round()),
      );
      drawLabel(
        canvas,
        'LaTeX  ✓  exact',
        at: Offset(chip.center.dx - 44, chip.center.dy - 7),
        size: 12,
        color: c.success,
        opacity: doneP,
      );
    }
  }

  void _corners(Canvas canvas, Rect r, Color color) {
    final p = Paint()
      ..color = color.withAlpha(200)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    const len = 12.0;
    final pts = [
      (Offset(r.left + 10, r.top + 10), 1, 1),
      (Offset(r.right - 10, r.top + 10), -1, 1),
      (Offset(r.left + 10, r.bottom - 10), 1, -1),
      (Offset(r.right - 10, r.bottom - 10), -1, -1),
    ];
    for (final (o, dx, dy) in pts) {
      canvas.drawLine(o, Offset(o.dx + len * dx, o.dy), p);
      canvas.drawLine(o, Offset(o.dx, o.dy + len * dy), p);
    }
  }

  @override
  bool shouldRepaint(covariant OcrPainter old) => old.t != t;
}
