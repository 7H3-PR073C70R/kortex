// CustomPainters draw sequential canvas calls; cascading hurts readability.
// ignore_for_file: cascade_invocations
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/illustrations/illustration_common.dart';

/// 1. INGESTION — Drop. Parse. Master.
class IngestionPainter extends CustomPainter {
  IngestionPainter(this.t, this.c);

  final double t;
  final AppThemeColorsExtension c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- The dropped document -------------------------------------------
    final dropP = eo(seg(t, 0, 0.18));
    final docW = w * 0.30;
    final docH = h * 0.54;
    final docX = w * 0.10;
    final docY = h * 0.24 + (1 - dropP) * (-h * 0.30);
    final docRect = Rect.fromLTWH(docX, docY, docW, docH);

    canvas.drawRRect(
      rr(docRect, 14),
      Paint()..color = c.surfaceElevated.withAlpha((235 * dropP).round()),
    );
    canvas.drawRRect(
      rr(docRect, 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = c.primary.withAlpha((150 * dropP).round()),
    );

    // Title bar + text lines. Lines "parse" (turn accent) as the scan
    // band passes over them.
    final scanActive = t > 0.20 && t < 0.52;
    final scanP = seg(t, 0.20, 0.50);
    const lineCount = 5;
    final contentTop = docY + docH * 0.30;
    final lineGap = docH * 0.12;
    final scanY = docY + docH * (0.22 + scanP * 0.66);

    // Header pill
    canvas.drawRRect(
      rr(
        Rect.fromLTWH(docX + docW * 0.14, docY + docH * 0.12, docW * 0.5, 8),
        4,
      ),
      Paint()..color = c.primary.withAlpha((220 * dropP).round()),
    );

    for (var i = 0; i < lineCount; i++) {
      final ly = contentTop + i * lineGap;
      final parsed = !scanActive ? (t >= 0.52) : (ly < scanY);
      final lw = docW * (0.66 - (i.isEven ? 0 : 0.14));
      canvas.drawRRect(
        rr(Rect.fromLTWH(docX + docW * 0.14, ly, lw, 5), 2.5),
        Paint()
          ..color = (parsed ? c.syllabotAccent : c.textMuted).withAlpha(
            (dropP * (parsed ? 230 : 130)).round(),
          ),
      );
    }

    // Scan band sweeping the document.
    if (scanActive) {
      final band = Paint()
        ..shader = ui.Gradient.linear(
          Offset(docX, scanY - 16),
          Offset(docX, scanY + 2),
          [c.syllabotAccent.withAlpha(0), c.syllabotAccent.withAlpha(70)],
        );
      canvas.drawRect(Rect.fromLTWH(docX, scanY - 16, docW, 18), band);
      canvas.drawLine(
        Offset(docX, scanY),
        Offset(docX + docW, scanY),
        Paint()
          ..color = c.syllabotAccent
          ..strokeWidth = 2,
      );
    }

    // --- Flow connector (doc -> cards) ----------------------------------
    final flowP = seg(t, 0.50, 0.62);
    if (flowP > 0) {
      final from = Offset(docX + docW + 6, docY + docH * 0.5);
      final to = Offset(w * 0.60 - 6, h * 0.5);
      final dash = Paint()
        ..color = c.textMuted.withAlpha((180 * flowP).round())
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      const segments = 6;
      for (var i = 0; i < segments; i += 2) {
        final a = i / segments;
        final b = (i + 0.6) / segments;
        canvas.drawLine(
          Offset.lerp(from, to, a)!,
          Offset.lerp(from, to, b)!,
          dash,
        );
      }
      // A knowledge packet traveling along the connector.
      final travel = (t * 2.2) % 1.0;
      if (t > 0.52) {
        canvas.drawCircle(
          Offset.lerp(from, to, travel)!,
          3.2,
          Paint()..color = c.syllabotAccent.withAlpha(220),
        );
      }
    }

    // --- Generated recall cards -----------------------------------------
    final cardX = w * 0.60;
    final cardW = w * 0.30;
    final cardH = h * 0.16;
    final accents = [c.success, c.syllabotAccent, c.warning];
    final ys = [h * 0.20, h * 0.42, h * 0.64];
    for (var i = 0; i < 3; i++) {
      final pop = eo(seg(t, 0.60 + i * 0.11, 0.74 + i * 0.11));
      if (pop <= 0) continue;
      _recallCard(
        canvas,
        Rect.fromLTWH(cardX, ys[i], cardW, cardH),
        pop,
        accents[i],
      );
    }
  }

  void _recallCard(Canvas canvas, Rect rect, double p, Color accent) {
    final scale = 0.9 + 0.1 * p;
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale);
    canvas.translate(-rect.center.dx, -rect.center.dy);

    canvas.drawRRect(
      rr(rect, 12),
      Paint()..color = c.surfaceElevated.withAlpha((240 * p).round()),
    );
    canvas.drawRRect(
      rr(rect, 12),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = accent.withAlpha((200 * p).round()),
    );
    // Status dot + two content lines.
    canvas.drawCircle(
      Offset(rect.left + 14, rect.top + rect.height * 0.32),
      4,
      Paint()..color = accent.withAlpha((255 * p).round()),
    );
    canvas.drawRRect(
      rr(
        Rect.fromLTWH(
          rect.left + 26,
          rect.top + rect.height * 0.32 - 3,
          rect.width * 0.55,
          6,
        ),
        3,
      ),
      Paint()..color = accent.withAlpha((200 * p).round()),
    );
    canvas.drawRRect(
      rr(
        Rect.fromLTWH(
          rect.left + 14,
          rect.top + rect.height * 0.66,
          rect.width * 0.68,
          5,
        ),
        2.5,
      ),
      Paint()..color = c.textMuted.withAlpha((170 * p).round()),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IngestionPainter old) => old.t != t;
}
