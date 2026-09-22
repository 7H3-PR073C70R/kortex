// CustomPainters draw with many sequential `canvas.*` calls; cascading them
// with `..` would chain unrelated draws and hurt readability, so this file
// opts out of that lint specifically.
// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

/// Text-matched onboarding motion graphics.
///
/// Each scene is a self-contained, looping vector animation drawn with
/// [CustomPainter] so it stays crisp at any size and honors the
/// "reduce motion" accessibility setting (it settles on its final frame
/// instead of animating). There is deliberately no ambient glow, aura, or
/// gradient bloom — the artwork carries meaning through motion alone, and
/// every scene illustrates the literal promise of its slide copy:
///
///  1. Drop → Parse → Master  (document ingestion into recall cards)
///  2. A scanner resolves math/chemistry glyphs line by line (OCR)
///  3. The Ebbinghaus forgetting curve held up by timed reviews (FSRS)
///  4. A confidence gauge calibrating toward exam-ready (Socratic)
class OnboardingIllustrations {
  const OnboardingIllustrations._();

  /// Slide 1: Drop. Parse. Master.
  static Widget documentIngestion({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _AnimatedScene(
      durationMs: 4200,
      width: width,
      height: height,
      painter: (colors, t) => _IngestionPainter(t, colors),
    );
  }

  /// Slide 2: Flawless Math & Science OCR.
  static Widget stemOcr({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _AnimatedScene(
      durationMs: 4000,
      width: width,
      height: height,
      painter: (colors, t) => _OcrPainter(t, colors),
    );
  }

  /// Slide 3: Forget About Forgetting.
  static Widget spacedRepetition({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _AnimatedScene(
      durationMs: 5200,
      width: width,
      height: height,
      painter: (colors, t) => _RetentionPainter(t, colors),
    );
  }

  /// Slide 4: Calibrate Your Confidence.
  static Widget socraticAi({
    BuildContext? context,
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
  }) {
    return _AnimatedScene(
      durationMs: 4600,
      width: width,
      height: height,
      painter: (colors, t) => _SocraticPainter(t, colors),
    );
  }
}

// =========================================================================
// Shared scaffolding
// =========================================================================

/// Wraps a looping [AnimationController] and rebuilds a [CustomPaint] each
/// frame. When the platform requests reduced motion, the loop never starts
/// and the scene renders its completed (t = 1.0) composition instead.
class _AnimatedScene extends StatefulWidget {
  const _AnimatedScene({
    required this.durationMs,
    required this.painter,
    this.width,
    this.height,
  });

  final int durationMs;
  final CustomPainter Function(AppThemeColorsExtension colors, double t)
  painter;
  final double? width;
  final double? height;

  @override
  State<_AnimatedScene> createState() => _AnimatedSceneState();
}

class _AnimatedSceneState extends State<_AnimatedScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.durationMs),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (disableAnimations) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 1.0;
    } else if (!_controller.isAnimating) {
      unawaited(_controller.repeat());
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final colors = context.colors;
            return CustomPaint(
              painter: widget.painter(colors, _controller.value),
            );
          },
        ),
      ),
    );
  }
}

/// Normalized sub-segment of the master timeline: 0 before [a], 1 after [b].
double _seg(double t, double a, double b) =>
    ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Ease-out cubic — fast departure, gentle settle.
double _eo(double v) => 1 - math.pow(1 - v, 3).toDouble();

RRect _rr(Rect rect, double radius) =>
    RRect.fromRectAndRadius(rect, Radius.circular(radius));

/// Paints a single line of text. Returns its size so callers can align.
Size _label(
  Canvas canvas,
  String text, {
  required Offset at,
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w600,
  double opacity = 1,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        color: color.withAlpha((opacity * 255).round()),
        fontWeight: weight,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, at);
  return painter.size;
}

// =========================================================================
// 1. INGESTION — Drop. Parse. Master.
// =========================================================================
class _IngestionPainter extends CustomPainter {
  _IngestionPainter(this.t, this.c);

  final double t;
  final AppThemeColorsExtension c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- The dropped document -------------------------------------------
    final dropP = _eo(_seg(t, 0, 0.18));
    final docW = w * 0.30;
    final docH = h * 0.54;
    final docX = w * 0.10;
    final docY = h * 0.24 + (1 - dropP) * (-h * 0.30);
    final docRect = Rect.fromLTWH(docX, docY, docW, docH);

    canvas.drawRRect(
      _rr(docRect, 14),
      Paint()..color = c.surfaceElevated.withAlpha((235 * dropP).round()),
    );
    canvas.drawRRect(
      _rr(docRect, 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = c.primary.withAlpha((150 * dropP).round()),
    );

    // Title bar + text lines. Lines "parse" (turn accent) as the scan
    // band passes over them.
    final scanActive = t > 0.20 && t < 0.52;
    final scanP = _seg(t, 0.20, 0.50);
    const lineCount = 5;
    final contentTop = docY + docH * 0.30;
    final lineGap = docH * 0.12;
    final scanY = docY + docH * (0.22 + scanP * 0.66);

    // Header pill
    canvas.drawRRect(
      _rr(
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
        _rr(Rect.fromLTWH(docX + docW * 0.14, ly, lw, 5), 2.5),
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
    final flowP = _seg(t, 0.50, 0.62);
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
      final pop = _eo(_seg(t, 0.60 + i * 0.11, 0.74 + i * 0.11));
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
    // Scale-in from 0.9 (never from zero) around the card center.
    final scale = 0.9 + 0.1 * p;
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale);
    canvas.translate(-rect.center.dx, -rect.center.dy);

    canvas.drawRRect(
      _rr(rect, 12),
      Paint()..color = c.surfaceElevated.withAlpha((240 * p).round()),
    );
    canvas.drawRRect(
      _rr(rect, 12),
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
      _rr(
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
      _rr(
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
  bool shouldRepaint(covariant _IngestionPainter old) => old.t != t;
}

// =========================================================================
// 2. STEM OCR — scanner resolves glyphs line by line
// =========================================================================
class _OcrPainter extends CustomPainter {
  _OcrPainter(this.t, this.c);

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
      _rr(sheet, 16),
      Paint()..color = c.surfaceElevated.withAlpha(235),
    );
    canvas.drawRRect(
      _rr(sheet, 16),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = c.surfaceBorder.withAlpha(160),
    );

    // Reticle corners for the "precision" read frame.
    _corners(canvas, sheet, c.syllabotAccent);

    // Scan travels top -> bottom over the sheet.
    final scanP = _seg(t, 0.06, 0.82);
    final scanY = sheet.top + 8 + scanP * (sheet.height - 16);

    final lineTop = sheet.top + sheet.height * 0.20;
    final lineGap = sheet.height * 0.18;
    for (var i = 0; i < _lines.length; i++) {
      final ly = lineTop + i * lineGap;
      final resolved = scanY >= ly;
      if (resolved) {
        _label(
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
          _rr(
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
    canvas.clipRRect(_rr(sheet, 16));
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
    final doneP = _eo(_seg(t, 0.84, 0.96));
    if (doneP > 0) {
      final chip = Rect.fromLTWH(
        sheet.center.dx - 60,
        sheet.bottom + 10,
        120,
        26,
      );
      canvas.drawRRect(
        _rr(chip, 13),
        Paint()..color = c.success.withAlpha((40 * doneP).round()),
      );
      canvas.drawRRect(
        _rr(chip, 13),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = c.success.withAlpha((200 * doneP).round()),
      );
      _label(
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
  bool shouldRepaint(covariant _OcrPainter old) => old.t != t;
}

// =========================================================================
// 3. RETENTION — the forgetting curve held up by timed reviews
// =========================================================================
class _RetentionPainter extends CustomPainter {
  _RetentionPainter(this.t, this.c);

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
    _label(
      canvas,
      'Retention',
      at: Offset(left, top - 18),
      size: 11,
      color: c.textSecondary,
    );
    _label(
      canvas,
      'Time →',
      at: Offset(right - 40, bottom + 8),
      size: 11,
      color: c.textSecondary,
    );

    // Reveal the curve left → right.
    final p = _seg(t, 0.08, 0.92);
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
      _label(
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
  bool shouldRepaint(covariant _RetentionPainter old) => old.t != t;
}

// =========================================================================
// 4. SOCRATIC — a confidence gauge calibrating toward exam-ready
// =========================================================================
class _SocraticPainter extends CustomPainter {
  _SocraticPainter(this.t, this.c);

  final double t;
  final AppThemeColorsExtension c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // --- Socratic hint dots (leads you there, never spills the answer) ---
    final bubble = Rect.fromLTWH(w * 0.10, h * 0.10, w * 0.34, 34);
    canvas.drawRRect(
      _rr(bubble, 14),
      Paint()..color = c.surfaceElevated.withAlpha(220),
    );
    canvas.drawRRect(
      _rr(bubble, 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = c.warning.withAlpha(150),
    );
    _label(
      canvas,
      '?',
      at: Offset(bubble.left + 12, bubble.top + 8),
      size: 16,
      color: c.warning,
    );
    for (var i = 0; i < 3; i++) {
      final lit = _seg(t, 0.20 + i * 0.16, 0.32 + i * 0.16);
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
    final value = _eo(_seg(t, 0.10, 0.72)) * 0.94;
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
    _labelCentered(
      canvas,
      '$pct%',
      Offset(cx, cy - 4),
      size: 30,
      color: c.textPrimary,
      weight: FontWeight.w800,
    );
    _labelCentered(
      canvas,
      'MASTERY',
      Offset(cx, cy + 18),
      size: 10,
      color: c.textSecondary,
      weight: FontWeight.w700,
    );

    // "Exam-ready" badge as the gauge nears its target.
    final readyP = _eo(_seg(t, 0.74, 0.9));
    if (readyP > 0) {
      const chipW = 128.0;
      final chip = Rect.fromLTWH(cx - chipW / 2, cy + radius * 0.52, chipW, 26);
      canvas.drawRRect(
        _rr(chip, 13),
        Paint()..color = c.success.withAlpha((35 * readyP).round()),
      );
      canvas.drawRRect(
        _rr(chip, 13),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = c.success.withAlpha((200 * readyP).round()),
      );
      _labelCentered(
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

  void _labelCentered(
    Canvas canvas,
    String text,
    Offset center, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w600,
    double opacity = 1,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color.withAlpha((opacity * 255).round()),
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _SocraticPainter old) => old.t != t;
}
