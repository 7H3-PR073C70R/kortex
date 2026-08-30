import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/typography/app_typography.dart';
import 'package:kortex/src/core/themes/typography/body.dart';
import 'package:kortex/src/core/themes/typography/callout.dart';
import 'package:kortex/src/core/themes/typography/caption.dart';
import 'package:kortex/src/core/themes/typography/code.dart';
import 'package:kortex/src/core/themes/typography/footnote.dart';
import 'package:kortex/src/core/themes/typography/headline.dart';
import 'package:kortex/src/core/themes/typography/large_title.dart';
import 'package:kortex/src/core/themes/typography/subhead.dart';
import 'package:kortex/src/core/themes/typography/title_1.dart';
import 'package:kortex/src/core/themes/typography/title_2.dart';
import 'package:kortex/src/core/themes/typography/title_3.dart';

@immutable
class TypographyThemeExtension
    extends ThemeExtension<TypographyThemeExtension> {
  const TypographyThemeExtension({
    required this.largeTitle,
    required this.title1,
    required this.title2,
    required this.title3,
    required this.headline,
    required this.body,
    required this.callout,
    required this.subhead,
    required this.footnote,
    required this.caption,
    required this.code,
  });

  /// Factory creating default typography instance
  factory TypographyThemeExtension.standard() {
    return TypographyThemeExtension(
      largeTitle: LargeTitle(),
      title1: Title1(),
      title2: Title2(),
      title3: Title3(),
      headline: Headline(),
      body: Body(),
      callout: Callout(),
      subhead: Subhead(),
      footnote: Footnote(),
      caption: Caption(),
      code: Code(),
    );
  }

  final AppTypography largeTitle;
  final AppTypography title1;
  final AppTypography title2;
  final AppTypography title3;
  final AppTypography headline;
  final AppTypography body;
  final AppTypography callout;
  final AppTypography subhead;
  final AppTypography footnote;
  final AppTypography caption;
  final AppTypography code;

  /// Material [TextTheme] bridge for Flutter core widget interoperability.
  TextTheme toTextTheme({required Color defaultColor}) {
    return TextTheme(
      displayLarge: largeTitle.bold.copyWith(color: defaultColor),
      displayMedium: title1.bold.copyWith(color: defaultColor),
      displaySmall: title2.bold.copyWith(color: defaultColor),
      headlineMedium: title3.semiBold.copyWith(color: defaultColor),
      headlineSmall: headline.semiBold.copyWith(color: defaultColor),
      titleLarge: headline.medium.copyWith(color: defaultColor),
      titleMedium: subhead.medium.copyWith(color: defaultColor),
      titleSmall: footnote.medium.copyWith(color: defaultColor),
      bodyLarge: body.regular.copyWith(color: defaultColor),
      bodyMedium: callout.regular.copyWith(color: defaultColor),
      bodySmall: footnote.regular.copyWith(color: defaultColor),
      labelLarge: subhead.semiBold.copyWith(color: defaultColor),
      labelMedium: footnote.medium.copyWith(color: defaultColor),
      labelSmall: caption.regular.copyWith(color: defaultColor),
    );
  }

  @override
  TypographyThemeExtension copyWith({
    AppTypography? largeTitle,
    AppTypography? title1,
    AppTypography? title2,
    AppTypography? title3,
    AppTypography? headline,
    AppTypography? body,
    AppTypography? callout,
    AppTypography? subhead,
    AppTypography? footnote,
    AppTypography? caption,
    AppTypography? code,
  }) {
    return TypographyThemeExtension(
      largeTitle: largeTitle ?? this.largeTitle,
      title1: title1 ?? this.title1,
      title2: title2 ?? this.title2,
      title3: title3 ?? this.title3,
      headline: headline ?? this.headline,
      body: body ?? this.body,
      callout: callout ?? this.callout,
      subhead: subhead ?? this.subhead,
      footnote: footnote ?? this.footnote,
      caption: caption ?? this.caption,
      code: code ?? this.code,
    );
  }

  @override
  TypographyThemeExtension lerp(
    ThemeExtension<TypographyThemeExtension>? other,
    double t,
  ) {
    if (other is! TypographyThemeExtension) return this;

    return TypographyThemeExtension(
      largeTitle: largeTitle.lerp(other.largeTitle, t),
      title1: title1.lerp(other.title1, t),
      title2: title2.lerp(other.title2, t),
      title3: title3.lerp(other.title3, t),
      headline: headline.lerp(other.headline, t),
      body: body.lerp(other.body, t),
      callout: callout.lerp(other.callout, t),
      subhead: subhead.lerp(other.subhead, t),
      footnote: footnote.lerp(other.footnote, t),
      caption: caption.lerp(other.caption, t),
      code: code.lerp(other.code, t),
    );
  }
}
