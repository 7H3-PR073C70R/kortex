import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

class Headline extends AppTypography {
  Headline({
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

  static const TextStyle _base = TextStyle(fontSize: 17);

  @override
  Headline copyWith({
    TextStyle? regular,
    TextStyle? medium,
    TextStyle? semiBold,
    TextStyle? bold,
  }) {
    return Headline(
      regular: regular ?? this.regular,
      medium: medium ?? this.medium,
      semiBold: semiBold ?? this.semiBold,
      bold: bold ?? this.bold,
    );
  }

  @override
  Headline lerp(covariant AppTypography other, double t) {
    if (other is! Headline) return this;

    return Headline(
      regular: TextStyle.lerp(regular, other.regular, t),
      medium: TextStyle.lerp(medium, other.medium, t),
      semiBold: TextStyle.lerp(semiBold, other.semiBold, t),
      bold: TextStyle.lerp(bold, other.bold, t),
    );
  }
}
