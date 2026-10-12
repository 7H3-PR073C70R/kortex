import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Custom painter that carves a rounded spotlight cutout out of a dark scrim.
class SpotlightPainter extends CustomPainter {
  const SpotlightPainter({
    required this.targetRect,
    required this.pulseValue,
    required this.accentColor,
    required this.scrimColor,
  });

  final Rect targetRect;
  final double pulseValue;
  final Color accentColor;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutRect = targetRect.inflate(8);
    final rrect = RRect.fromRectAndRadius(
      cutoutRect,
      const Radius.circular(AppRadius.card),
    );

    final scrimPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas
      ..drawPath(scrimPath, Paint()..color = scrimColor)
      ..drawRRect(
        rrect,
        Paint()
          ..color = accentColor.withAlpha((180 * pulseValue).toInt())
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
  }

  @override
  bool shouldRepaint(covariant SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.scrimColor != scrimColor;
  }
}
