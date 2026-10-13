import 'package:flutter/material.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/rocket/rocket_flight_models.dart';

/// Custom Canvas Painter for Starfield, Speed Streaks, and Thruster Particles.
class CosmicFlightPainter extends CustomPainter {
  CosmicFlightPainter({
    required this.stars,
    required this.particles,
    required this.machSpeed,
    required this.isWarping,
    required this.warpProgress,
    required this.primaryColor,
    required this.accentColor,
    required this.warningColor,
    required this.whiteColor,
    required this.surfaceColor,
  });

  final List<Offset> stars;
  final List<FlightParticle> particles;
  final double machSpeed;
  final bool isWarping;
  final double warpProgress;
  final Color primaryColor;
  final Color accentColor;
  final Color warningColor;
  final Color whiteColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Deep cosmic background gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          surfaceColor,
          surfaceColor.withAlpha(240),
          primaryColor.withAlpha(isWarping ? 80 : 35),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final starPaint = Paint()..color = whiteColor;
    final streakPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final streakLength = isWarping
        ? 80.0 + (warpProgress * 200)
        : machSpeed * 3.5;

    // Draw Starfield & Warp Streaks
    for (final star in stars) {
      final sx = star.dx * size.width;
      final sy = star.dy * size.height;

      if (streakLength > 6) {
        streakPaint
          ..strokeWidth = isWarping ? 2.5 : 1.5
          ..color = (isWarping ? accentColor : whiteColor).withAlpha(
            (140 + (warpProgress * 115)).toInt().clamp(0, 255),
          );
        canvas.drawLine(
          Offset(sx, sy),
          Offset(sx, sy + streakLength),
          streakPaint,
        );
      } else {
        canvas.drawCircle(
          Offset(sx, sy),
          1.2,
          starPaint..color = whiteColor.withAlpha(160),
        );
      }
    }

    // Draw Thruster Particles
    for (final p in particles) {
      final alpha = ((p.life / p.maxLife) * 255).toInt().clamp(0, 255);
      final pPaint = Paint()..color = p.color.withAlpha(alpha);
      canvas.drawCircle(Offset(p.x, p.y), p.radius, pPaint);
    }

    // Warp Shockwave Expanding Rings
    if (isWarping) {
      final center = Offset(size.width / 2, size.height / 2);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = accentColor.withAlpha(
          ((1 - warpProgress) * 220).toInt().clamp(0, 255),
        );

      final radius = warpProgress * size.height * 0.9;
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CosmicFlightPainter oldDelegate) => true;
}
