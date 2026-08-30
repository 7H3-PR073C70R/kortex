import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

/// Monospaced typography for STEM equations, raw LaTeX, and code snippets.
class Code extends AppTypography {
  Code({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) : super(
          regular: regular ?? _base,
          medium: medium ?? _base.copyWith(fontWeight: FontWeight.w500),
          semiBold: semiBold ?? _base.copyWith(fontWeight: FontWeight.w600),
          bold: bold ?? _base.copyWith(fontWeight: FontWeight.w700),
        );

  static final TextStyle _base = GoogleFonts.jetBrainsMono(
    fontSize: 14,
    height: 1.45,
    letterSpacing: -0.1,
  );

  @override
  Code copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) {
    return Code(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semiBold: semiBold ?? this.semiBold,
      bold: bold ?? this.bold,
    );
  }

  @override
  Code lerp(covariant AppTypography other, double t) {
    if (other is! Code) return this;

    return Code(
      regular: TextStyle.lerp(regular, other.regular, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      semiBold: TextStyle.lerp(semiBold, other.semiBold, t),
      bold: TextStyle.lerp(bold, other.bold, t),
    );
  }
}
