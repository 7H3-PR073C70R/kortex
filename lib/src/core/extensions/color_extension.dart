import 'package:flutter/material.dart';

extension MaterialColorExtension on Color {
  MaterialColor toMaterialColor({
    Color? shade50,
    Color? shade100,
    Color? shade200,
    Color? shade300,
    Color? shade400,
    Color? shade500,
    Color? shade600,
    Color? shade700,
    Color? shade800,
    Color? shade900,
  }) {
    return MaterialColor(
      _floatToInt8(a) << 24 |
          _floatToInt8(r) << 16 |
          _floatToInt8(g) << 8 |
          _floatToInt8(b) << 0,
      <int, Color>{
        50: shade50 ?? _shade(50),
        100: shade100 ?? _shade(100),
        200: shade200 ?? _shade(200),
        300: shade300 ?? _shade(300),
        400: shade400 ?? _shade(300),
        500: shade500 ?? _shade(500),
        600: shade600 ?? _shade(600),
        700: shade700 ?? _shade(700),
        800: shade800 ?? _shade(800),
        900: shade900 ?? _shade(900),
      },
    );
  }

  int _floatToInt8(double x) {
    return (x * 255.0).round() & 0xff;
  }

  Color _shade(int strength) {
    final opacity = strength / 1000;
    return Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), opacity);
  }
}
