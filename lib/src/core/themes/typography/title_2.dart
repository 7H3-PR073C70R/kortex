import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

class Title2 extends AppTypography {
  Title2({
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

  static final TextStyle _base = GoogleFonts.plusJakartaSans(
    fontSize: 22,
    height: 1.3,
    letterSpacing: -0.2,
  );

  @override
  Title2 copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) {
    return Title2(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semiBold: semiBold ?? this.semiBold,
      bold: bold ?? this.bold,
    );
  }

  @override
  Title2 lerp(covariant AppTypography other, double t) {
    if (other is! Title2) return this;

    return Title2(
      regular: TextStyle.lerp(regular, other.regular, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      semiBold: TextStyle.lerp(semiBold, other.semiBold, t),
      bold: TextStyle.lerp(bold, other.bold, t),
    );
  }
}
