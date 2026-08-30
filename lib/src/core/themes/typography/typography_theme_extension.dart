import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';

@immutable
class TypographyThemeExtension
    extends ThemeExtension<TypographyThemeExtension> {
  const TypographyThemeExtension({
    required this.body,
    required this.callout,
    required this.caption,
    required this.footnote,
    required this.headline,
    required this.largeTitle,
    required this.subhead,
    required this.title1,
    required this.title2,
    required this.title3,
  });

  final AppTypography callout;
  final AppTypography footnote;
  final AppTypography headline;
  final AppTypography largeTitle;
  final AppTypography subhead;
  final AppTypography body;
  final AppTypography title1;
  final AppTypography title2;
  final AppTypography title3;
  final AppTypography caption;

  @override
  TypographyThemeExtension copyWith({
    AppTypography? callout,
    AppTypography? footnote,
    AppTypography? headline,
    AppTypography? largeTitle,
    AppTypography? subhead,
    AppTypography? body,
    AppTypography? title1,
    AppTypography? title2,
    AppTypography? title3,
    AppTypography? caption,
  }) {
    return TypographyThemeExtension(
      body: body ?? this.body,
      callout: callout ?? this.callout,
      caption: caption ?? this.caption,
      footnote: footnote ?? this.footnote,
      headline: headline ?? this.headline,
      largeTitle: largeTitle ?? this.largeTitle,
      subhead: subhead ?? this.subhead,
      title1: title1 ?? this.title1,
      title2: title2 ?? this.title2,
      title3: title3 ?? this.title3,
    );
  }

  @override
  TypographyThemeExtension lerp(
    ThemeExtension<TypographyThemeExtension>? other,
    double t,
  ) {
    if (other is! TypographyThemeExtension) return this;

    return TypographyThemeExtension(
      body: body.lerp(other.body, t),
      callout: callout.lerp(other.callout, t),
      caption: caption.lerp(other.caption, t),
      footnote: footnote.lerp(other.footnote, t),
      headline: headline.lerp(other.headline, t),
      largeTitle: largeTitle.lerp(other.largeTitle, t),
      subhead: subhead.lerp(other.subhead, t),
      title1: title1.lerp(other.title1, t),
      title2: title2.lerp(other.title2, t),
      title3: title3.lerp(other.title3, t),
    );
  }
}
