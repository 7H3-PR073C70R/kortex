import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

class LargeTitle extends AppTypography {
  LargeTitle({
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
    fontSize: 34,
    height: 1.2,
    letterSpacing: -0.4,
  );

  @override
  LargeTitle copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) {
    return LargeTitle(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semiBold: semiBold ?? this.semiBold,
      bold: bold ?? this.bold,
    );
  }

  @override
  LargeTitle lerp(covariant AppTypography other, double t) {
    if (other is! LargeTitle) return this;

    return LargeTitle(
      regular: TextStyle.lerp(regular, other.regular, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      semiBold: TextStyle.lerp(semiBold, other.semiBold, t),
      bold: TextStyle.lerp(bold, other.bold, t),
    );
  }
}
