import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

/// An expressive, animated illustration of a teddy bear mascot.
///
/// Supports:
/// - Sad/Lonely mode: droopy ears, melancholic tear, sad mouth.
/// - Happy/Celebratory mode: perky bouncy ears, beaming smile, sparkling eyes,
///   and floating celebratory sparkles/stars.
class LonelyTeddyBearWidget extends StatefulWidget {
  const LonelyTeddyBearWidget({
    this.size = 110,
    this.isHappy = false,
    super.key,
  });

  final double size;
  final bool isHappy;

  @override
  State<LonelyTeddyBearWidget> createState() => _LonelyTeddyBearWidgetState();
}

class _LonelyTeddyBearWidgetState extends State<LonelyTeddyBearWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.isHappy ? 1600 : 2400),
    );
    unawaited(_controller.repeat(reverse: true));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final breath = _controller.value;
        final floatY = math.sin(breath * math.pi) * (widget.isHappy ? 6.0 : 4.0);
        final earMotion = math.sin(breath * math.pi) * (widget.isHappy ? -0.04 : 0.05);

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ambient atmospheric aura
              Container(
                width: widget.size * 0.95,
                height: widget.size * 0.95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (widget.isHappy
                              ? colors.warning
                              : (isDark ? colors.syllabotAccent : colors.primary))
                          .withAlpha(widget.isHappy ? (isDark ? 45 : 30) : (isDark ? 35 : 20)),
                      colors.transparent,
                    ],
                  ),
                ),
              ),

              // 2. Animated Mascot Custom Painter
              Transform.translate(
                offset: Offset(0, floatY),
                child: CustomPaint(
                  size: Size(widget.size * 0.85, widget.size * 0.85),
                  painter: _TeddyBearPainter(
                    breath: breath,
                    earMotion: earMotion,
                    isHappy: widget.isHappy,
                    isDark: isDark,
                    themeColors: colors,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeddyBearPainter extends CustomPainter {
  _TeddyBearPainter({
    required this.breath,
    required this.earMotion,
    required this.isHappy,
    required this.isDark,
    required this.themeColors,
  });

  final double breath;
  final double earMotion;
  final bool isHappy;
  final bool isDark;
  final AppThemeColorsExtension themeColors;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final bearColor = isHappy
        ? (isDark ? const Color(0xFF7D5A88) : const Color(0xFFD6A9C5))
        : (isDark ? const Color(0xFF6B5876) : const Color(0xFFC7A7B8));
    final bearHighlight = isHappy
        ? (isDark ? const Color(0xFF9E74AB) : const Color(0xFFF3C7E3))
        : (isDark ? const Color(0xFF867094) : const Color(0xFFE2C9D7));
    final innerEarColor = isDark
        ? const Color(0xFF9E7B9B)
        : const Color(0xFFF3D6E4);
    final muzzleColor = isDark
        ? const Color(0xFF8F7A9E)
        : const Color(0xFFF5E4EE);
    final darkDetailColor = isDark
        ? const Color(0xFF231C28)
        : const Color(0xFF3F2F3B);

    final bearPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.3),
        radius: 0.8,
        colors: [bearHighlight, bearColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final innerEarPaint = Paint()..color = innerEarColor;
    final muzzlePaint = Paint()..color = muzzleColor;
    final detailPaint = Paint()
      ..color = darkDetailColor
      ..style = PaintingStyle.fill;
    final strokeDetailPaint = Paint()
      ..color = darkDetailColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.024
      ..strokeCap = StrokeCap.round;

    // A. Ears
    final leftEarCenter = Offset(w * 0.24, h * 0.24 + (earMotion * 8));
    final rightEarCenter = Offset(w * 0.76, h * 0.24 + (earMotion * 8));
    final earRadius = w * (isHappy ? 0.18 : 0.17);

    canvas
      ..drawCircle(leftEarCenter, earRadius, bearPaint)
      ..drawCircle(leftEarCenter, earRadius * 0.58, innerEarPaint)
      ..drawCircle(rightEarCenter, earRadius, bearPaint)
      ..drawCircle(rightEarCenter, earRadius * 0.58, innerEarPaint);

    // B. Head
    final headCenter = Offset(center.dx, center.dy * 0.95);
    final headRadius = w * 0.38 * (1.0 + (breath * 0.015));
    canvas.drawCircle(headCenter, headRadius, bearPaint);

    // C. Muzzle
    final muzzleCenter = Offset(headCenter.dx, headCenter.dy + (w * 0.1));
    final muzzleRect = Rect.fromCenter(
      center: muzzleCenter,
      width: w * 0.36,
      height: h * 0.25,
    );
    canvas.drawOval(muzzleRect, muzzlePaint);

    // D. Nose
    final noseCenter = Offset(muzzleCenter.dx, muzzleCenter.dy - (h * 0.03));
    final nosePath = Path()
      ..moveTo(noseCenter.dx - (w * 0.042), noseCenter.dy - (h * 0.02))
      ..quadraticBezierTo(
        noseCenter.dx,
        noseCenter.dy - (h * 0.03),
        noseCenter.dx + (w * 0.042),
        noseCenter.dy - (h * 0.02),
      )
      ..quadraticBezierTo(
        noseCenter.dx,
        noseCenter.dy + (h * 0.035),
        noseCenter.dx - (w * 0.042),
        noseCenter.dy - (h * 0.02),
      );
    canvas.drawPath(nosePath, detailPaint);

    // E. Mouth (Sad vs Happy Smile)
    final mouthCenter = Offset(noseCenter.dx, noseCenter.dy + (h * 0.045));
    final mouthPath = Path();
    if (isHappy) {
      // Radiant Happy Smile
      mouthPath
        ..moveTo(mouthCenter.dx - (w * 0.052), mouthCenter.dy - (h * 0.008))
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + (h * 0.038),
          mouthCenter.dx + (w * 0.052),
          mouthCenter.dy - (h * 0.008),
        );
      canvas.drawPath(mouthPath, strokeDetailPaint);

      // Open smile fill for extra happiness
      final smileFillPaint = Paint()
        ..color = const Color(0xFFFF5277).withAlpha(isDark ? 180 : 220)
        ..style = PaintingStyle.fill;
      final smileFillPath = Path()
        ..moveTo(mouthCenter.dx - (w * 0.045), mouthCenter.dy)
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy + (h * 0.035),
          mouthCenter.dx + (w * 0.045),
          mouthCenter.dy,
        )
        ..close();
      canvas.drawPath(smileFillPath, smileFillPaint);
    } else {
      // Sad Downturned Mouth
      mouthPath
        ..moveTo(mouthCenter.dx - (w * 0.04), mouthCenter.dy + (h * 0.02))
        ..quadraticBezierTo(
          mouthCenter.dx,
          mouthCenter.dy - (h * 0.01),
          mouthCenter.dx + (w * 0.04),
          mouthCenter.dy + (h * 0.02),
        );
      canvas.drawPath(mouthPath, strokeDetailPaint);
    }

    // F. Eyes
    final leftEyeCenter = Offset(w * 0.36, h * 0.39);
    final rightEyeCenter = Offset(w * 0.64, h * 0.39);
    final eyeRadius = w * (isHappy ? 0.048 : 0.045);

    canvas
      ..drawCircle(leftEyeCenter, eyeRadius, detailPaint)
      ..drawCircle(rightEyeCenter, eyeRadius, detailPaint);

    // Eye Twinkles
    final twinklePaint = Paint()..color = themeColors.white;
    canvas
      ..drawCircle(
        leftEyeCenter + Offset(-eyeRadius * 0.3, -eyeRadius * 0.3),
        eyeRadius * (isHappy ? 0.42 : 0.35),
        twinklePaint,
      )
      ..drawCircle(
        rightEyeCenter + Offset(-eyeRadius * 0.3, -eyeRadius * 0.3),
        eyeRadius * (isHappy ? 0.42 : 0.35),
        twinklePaint,
      );

    if (isHappy) {
      // Secondary tiny twinkle for sparkling eyes
      canvas
        ..drawCircle(
          leftEyeCenter + Offset(eyeRadius * 0.3, eyeRadius * 0.3),
          eyeRadius * 0.22,
          twinklePaint,
        )
        ..drawCircle(
          rightEyeCenter + Offset(eyeRadius * 0.3, eyeRadius * 0.3),
          eyeRadius * 0.22,
          twinklePaint,
        );
    }

    // Eyebrows (Sad vs Cheerful)
    if (isHappy) {
      final leftBrow = Path()
        ..moveTo(w * 0.29, h * 0.33)
        ..quadraticBezierTo(w * 0.35, h * 0.29, w * 0.41, h * 0.33);
      final rightBrow = Path()
        ..moveTo(w * 0.59, h * 0.33)
        ..quadraticBezierTo(w * 0.65, h * 0.29, w * 0.71, h * 0.33);
      canvas
        ..drawPath(leftBrow, strokeDetailPaint)
        ..drawPath(rightBrow, strokeDetailPaint);
    } else {
      final leftBrow = Path()
        ..moveTo(w * 0.30, h * 0.34)
        ..lineTo(w * 0.40, h * 0.31);
      final rightBrow = Path()
        ..moveTo(w * 0.70, h * 0.34)
        ..lineTo(w * 0.60, h * 0.31);
      canvas
        ..drawPath(leftBrow, strokeDetailPaint)
        ..drawPath(rightBrow, strokeDetailPaint);
    }

    // G. Soft Rosy Blush Cheeks
    final blushColor = isHappy ? const Color(0xFFFF4D6D) : const Color(0xFFFF6B81);
    final blushPaint = Paint()
      ..color = blushColor.withAlpha(isDark ? (isHappy ? 80 : 60) : (isHappy ? 95 : 75));
    canvas
      ..drawCircle(Offset(w * 0.28, h * 0.48), w * (isHappy ? 0.062 : 0.055), blushPaint)
      ..drawCircle(Offset(w * 0.72, h * 0.48), w * (isHappy ? 0.062 : 0.055), blushPaint);

    if (isHappy) {
      // H. Floating Celebratory Stars ✨
      _drawSparkle(canvas, Offset(w * 0.12, h * 0.25 - breath * 4), w * 0.035, themeColors.warning);
      _drawSparkle(canvas, Offset(w * 0.88, h * 0.28 + breath * 3), w * 0.04, themeColors.warning);
      _drawSparkle(canvas, Offset(w * 0.82, h * 0.62 - breath * 2), w * 0.028, themeColors.primary);
    } else {
      // Single Sad Tear
      final tearY = h * 0.45 + (breath * h * 0.03);
      final tearPaint = Paint()
        ..color = const Color(0xFF60A5FA).withAlpha((180 + breath * 75).toInt());
      canvas.drawCircle(Offset(w * 0.33, tearY), w * 0.018, tearPaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset pos, double radius, Color color) {
    final paint = Paint()
      ..color = color.withAlpha((180 + breath * 70).toInt())
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(pos.dx, pos.dy - radius)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx + radius, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy + radius)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx - radius, pos.dy)
      ..quadraticBezierTo(pos.dx, pos.dy, pos.dx, pos.dy - radius)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TeddyBearPainter oldDelegate) {
    return oldDelegate.breath != breath ||
        oldDelegate.earMotion != earMotion ||
        oldDelegate.isHappy != isHappy;
  }
}
