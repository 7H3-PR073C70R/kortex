import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

class Footnote extends AppTypography {
  Footnote({
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
    fontSize: 13,
    height: 1.35,
    letterSpacing: 0.1,
  );

  @override
  Footnote copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) {
    return Footnote(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semiBold: semiBold ?? this.semiBold,
      bold: bold ?? this.bold,
    );
  }

  @override
  Footnote lerp(covariant AppTypography other, double t) {
    if (other is! Footnote) return this;

    return Footnote(
      regular: TextStyle.lerp(regular, other.regular, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      semiBold: TextStyle.lerp(semiBold, other.semiBold, t),
      bold: TextStyle.lerp(bold, other.bold, t),
    );
  }
}
