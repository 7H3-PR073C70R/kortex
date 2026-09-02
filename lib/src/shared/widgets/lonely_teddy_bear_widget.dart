import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';

/// A charming, animated illustration of a lonely/unhappy teddy bear.
///
/// Features:
/// - Smooth animated breathing and subtle head tilt.
/// - Expressive sad/droopy ears and twinkling melancholic eyes.
/// - Soft atmospheric glow and floating sparkles.
class LonelyTeddyBearWidget extends StatefulWidget {
  const LonelyTeddyBearWidget({
    this.size = 110,
    super.key,
  });

  final double size;

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
      duration: const Duration(milliseconds: 2400),
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
        final floatY = math.sin(breath * math.pi) * 4.0;
        final earDroop = math.sin(breath * math.pi) * 0.05;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ambient loneliness aura / soft glow
              Container(
                width: widget.size * 0.9,
                height: widget.size * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDark ? colors.syllabotAccent : colors.primary)
                          .withAlpha(isDark ? 35 : 20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 2. Lonely Floating Teddy Bear
              Transform.translate(
                offset: Offset(0, floatY),
                child: CustomPaint(
                  size: Size(widget.size * 0.85, widget.size * 0.85),
                  painter: _TeddyBearPainter(
                    breath: breath,
                    earDroop: earDroop,
                    isDark: isDark,
                    primaryColor: colors.primary,
                    accentColor: colors.syllabotAccent,
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
    required this.earDroop,
    required this.isDark,
    required this.primaryColor,
    required this.accentColor,
  });

  final double breath;
  final double earDroop;
  final bool isDark;
  final Color primaryColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final bearColor =
        isDark ? const Color(0xFF6B5876) : const Color(0xFFC7A7B8);
    final bearHighlight =
        isDark ? const Color(0xFF867094) : const Color(0xFFE2C9D7);
    final innerEarColor =
        isDark ? const Color(0xFF9E7B9B) : const Color(0xFFF3D6E4);
    final muzzleColor =
        isDark ? const Color(0xFF8F7A9E) : const Color(0xFFF5E4EE);
    final darkDetailColor =
        isDark ? const Color(0xFF231C28) : const Color(0xFF3F2F3B);

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

    // A. Droopy Ears
    final leftEarCenter = Offset(w * 0.24, h * 0.24 + (earDroop * 8));
    final rightEarCenter = Offset(w * 0.76, h * 0.24 + (earDroop * 8));
    final earRadius = w * 0.17;

    // Left Ear
    canvas
      ..drawCircle(leftEarCenter, earRadius, bearPaint)
      ..drawCircle(leftEarCenter, earRadius * 0.58, innerEarPaint)
      ..drawCircle(rightEarCenter, earRadius, bearPaint)
      ..drawCircle(rightEarCenter, earRadius * 0.58, innerEarPaint);

    // B. Head Shape
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + h * 0.04),
        width: w * 0.72,
        height: h * 0.68,
      ),
      Radius.circular(w * 0.34),
    );
    canvas.drawRRect(headRect, bearPaint);

    // C. Soft Muzzle / Snout
    final muzzleRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + h * 0.14),
      width: w * 0.38,
      height: h * 0.28,
    );
    canvas.drawOval(muzzleRect, muzzlePaint);

    // D. Cute Triangular Sad Nose
    final nosePath = Path()
      ..moveTo(center.dx - w * 0.05, center.dy + h * 0.07)
      ..lineTo(center.dx + w * 0.05, center.dy + h * 0.07)
      ..quadraticBezierTo(
        center.dx,
        center.dy + h * 0.13,
        center.dx - w * 0.05,
        center.dy + h * 0.07,
      );
    canvas.drawPath(nosePath, detailPaint);

    // E. Unhappy / Downturned Little Mouth
    final mouthPath = Path()
      ..moveTo(center.dx - w * 0.06, center.dy + h * 0.20)
      ..quadraticBezierTo(
        center.dx,
        center.dy + h * 0.15,
        center.dx + w * 0.06,
        center.dy + h * 0.20,
      );
    canvas.drawPath(mouthPath, strokeDetailPaint);

    // F. Lonely Melancholic Eyes with Sad Angled Eyebrows
    final leftEyeCenter = Offset(w * 0.36, h * 0.39);
    final rightEyeCenter = Offset(w * 0.64, h * 0.39);
    final eyeRadius = w * 0.045;

    // Eyes
    canvas
      ..drawCircle(leftEyeCenter, eyeRadius, detailPaint)
      ..drawCircle(rightEyeCenter, eyeRadius, detailPaint);

    // Eye Twinkles
    final twinklePaint = Paint()..color = Colors.white;
    canvas
      ..drawCircle(
        leftEyeCenter + Offset(-eyeRadius * 0.3, -eyeRadius * 0.3),
        eyeRadius * 0.35,
        twinklePaint,
      )
      ..drawCircle(
        rightEyeCenter + Offset(-eyeRadius * 0.3, -eyeRadius * 0.3),
        eyeRadius * 0.35,
        twinklePaint,
      );

    // Sad Downturned Eyebrows
    final leftBrow = Path()
      ..moveTo(w * 0.30, h * 0.34)
      ..lineTo(w * 0.40, h * 0.31);
    final rightBrow = Path()
      ..moveTo(w * 0.70, h * 0.34)
      ..lineTo(w * 0.60, h * 0.31);
    canvas
      ..drawPath(leftBrow, strokeDetailPaint)
      ..drawPath(rightBrow, strokeDetailPaint);

    // G. Soft Rosy Blush Cheeks
    final blushPaint = Paint()
      ..color = const Color(0xFFFF6B81).withAlpha(isDark ? 60 : 75);
    canvas
      ..drawCircle(Offset(w * 0.28, h * 0.48), w * 0.055, blushPaint)
      ..drawCircle(Offset(w * 0.72, h * 0.48), w * 0.055, blushPaint);

    // H. Tiny Sparkling Single Tear on Cheerful Face
    final tearY = h * 0.45 + (breath * h * 0.03);
    final tearPaint = Paint()
      ..color =
          const Color(0xFF60A5FA).withAlpha((180 + breath * 75).toInt());
    canvas.drawCircle(Offset(w * 0.33, tearY), w * 0.018, tearPaint);
  }

  @override
  bool shouldRepaint(covariant _TeddyBearPainter oldDelegate) {
    return oldDelegate.breath != breath || oldDelegate.earDroop != earDroop;
  }
}
