import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

class ShapeShadowPainter extends CustomPainter {
  const ShapeShadowPainter({
    required this.clipper,
    required this.color,
    required this.shadowColor,
    required this.elevation,
  });

  final CustomClipper<Path> clipper;
  final Color color;
  final Color shadowColor;
  final double elevation;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    if (elevation > 0) {
      canvas.drawShadow(path, shadowColor, elevation, false);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant ShapeShadowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.shadowColor != shadowColor ||
      oldDelegate.elevation != elevation;
}

class LoginCardClipper extends CustomClipper<Path> {
  const LoginCardClipper({
    required this.slantHeight,
  });

  static const double radius = AppRadius.sheet;
  final double slantHeight;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, w / 4);
    final slope = slantHeight / w;
    final leftY = (h - slantHeight).clamp(0.0, h);

    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h - slope * r)
      ..lineTo(r, leftY + slope * r)
      ..quadraticBezierTo(0, leftY, 0, leftY - r)
      ..lineTo(0, r)
      ..close();
  }

  @override
  bool shouldReclip(covariant LoginCardClipper oldClipper) =>
      oldClipper.slantHeight != slantHeight;
}

class SignupCardClipper extends CustomClipper<Path> {
  const SignupCardClipper({
    required this.slantHeight,
  });

  static const double radius = AppRadius.sheet;
  final double slantHeight;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final r = radius.clamp(0.0, w / 4);
    final slope = slantHeight / w;

    return Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, slope * r)
      ..lineTo(w - r, slantHeight - slope * r)
      ..quadraticBezierTo(w, slantHeight, w, slantHeight + r)
      ..lineTo(w, h - r)
      ..quadraticBezierTo(w, h, w - r, h)
      ..lineTo(r, h)
      ..quadraticBezierTo(0, h, 0, h - r)
      ..lineTo(0, r)
      ..close();
  }

  @override
  bool shouldReclip(covariant SignupCardClipper oldClipper) =>
      oldClipper.slantHeight != slantHeight;
}
