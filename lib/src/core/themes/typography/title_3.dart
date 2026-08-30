import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

class Title3 extends AppTypography {
  Title3({
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
    fontSize: 20,
    height: 1.35,
    letterSpacing: -0.15,
  );

  @override
  Title3 copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) {
    return Title3(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semiBold: semiBold ?? this.semiBold,
      bold: bold ?? this.bold,
    );
  }

  @override
  Title3 lerp(covariant AppTypography other, double t) {
    if (other is! Title3) return this;

    return Title3(
      regular: TextStyle.lerp(regular, other.regular, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      semiBold: TextStyle.lerp(semiBold, other.semiBold, t),
      bold: TextStyle.lerp(bold, other.bold, t),
    );
  }
}
