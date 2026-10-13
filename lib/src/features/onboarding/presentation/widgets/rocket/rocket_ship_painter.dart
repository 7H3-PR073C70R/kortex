import 'package:flutter/material.dart';

/// Custom Vector Painter for Sleek Spaceship with Dynamic Thruster Plumes.
class RocketShipPainter extends CustomPainter {
  RocketShipPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.whiteColor,
    required this.warningColor,
    required this.isTurbo,
  });

  final Color primaryColor;
  final Color accentColor;
  final Color whiteColor;
  final Color warningColor;
  final bool isTurbo;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // 1. Dynamic Flame Nozzle
    final flameHeight = isTurbo ? 42.0 : 28.0;
    final flamePath = Path()
      ..moveTo(cx - 8, size.height * 0.75)
      ..quadraticBezierTo(
        cx,
        size.height * 0.75 + flameHeight,
        cx + 8,
        size.height * 0.75,
      )
      ..close();

    final flamePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          warningColor,
          accentColor,
          accentColor.withAlpha(0),
        ],
      ).createShader(
        Rect.fromLTWH(cx - 12, size.height * 0.75, 24, flameHeight),
      );
    canvas.drawPath(flamePath, flamePaint);

    // 2. Aerodynamic Wings / Fins
    final wingPath = Path()
      // Left wing
      ..moveTo(cx - 10, size.height * 0.52)
      ..lineTo(cx - 28, size.height * 0.74)
      ..lineTo(cx - 10, size.height * 0.70)
      // Right wing
      ..moveTo(cx + 10, size.height * 0.52)
      ..lineTo(cx + 28, size.height * 0.74)
      ..lineTo(cx + 10, size.height * 0.70)
      ..close();

    final wingPaint = Paint()..color = accentColor;
    canvas.drawPath(wingPath, wingPaint);

    // 3. Rocket Fuselage Body
    final bodyPath = Path()
      ..moveTo(cx, size.height * 0.08) // Nose cone tip
      ..cubicTo(
        cx + 18,
        size.height * 0.30,
        cx + 16,
        size.height * 0.65,
        cx + 12,
        size.height * 0.74,
      )
      ..lineTo(cx - 12, size.height * 0.74)
      ..cubicTo(
        cx - 16,
        size.height * 0.65,
        cx - 18,
        size.height * 0.30,
        cx,
        size.height * 0.08,
      )
      ..close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          whiteColor,
          whiteColor.withAlpha(230),
          primaryColor.withAlpha(120),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(bodyPath, bodyPaint);

    // 4. Cockpit Windshield Visor
    final visorPaint = Paint()..color = primaryColor;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.35),
        width: 12,
        height: 18,
      ),
      visorPaint,
    );

    // Visor Glass Glare
    final glarePaint = Paint()..color = whiteColor.withAlpha(180);
    canvas.drawCircle(Offset(cx - 2, size.height * 0.32), 2.5, glarePaint);
  }

  @override
  bool shouldRepaint(covariant RocketShipPainter oldDelegate) => true;
}
