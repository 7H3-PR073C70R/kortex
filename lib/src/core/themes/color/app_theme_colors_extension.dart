import 'package:flutter/material.dart';

@immutable
class AppThemeColorsExtension extends ThemeExtension<AppThemeColorsExtension> {
  const AppThemeColorsExtension({
    required this.gray,
    required this.success,
    required this.error,
    required this.primary,
    required this.white,
    required this.disable,
    required this.button,
    required this.darkBlueBG,
    required this.offWhite,
    required this.text,
    required this.darkText,
    required this.lightModeGray,
    required this.black,
    required this.darkBorder,
    required this.successSecondary,
    required this.accent,
  });

  final MaterialColor gray;
  final MaterialColor success;
  final MaterialColor error;
  final MaterialColor primary;
  final MaterialColor white;
  final MaterialColor disable;
  final MaterialColor button;
  final MaterialColor darkBlueBG;
  final MaterialColor offWhite;
  final MaterialColor text;
  final MaterialColor darkText;
  final MaterialColor lightModeGray;
  final MaterialColor black;
  final MaterialColor darkBorder;
  final MaterialColor successSecondary;
  final MaterialColor accent;

  @override
  AppThemeColorsExtension copyWith({
    MaterialColor? gray,
    MaterialColor? success,
    MaterialColor? error,
    MaterialColor? primary,
    MaterialColor? white,
    MaterialColor? disable,
    MaterialColor? button,
    MaterialColor? darkBlueBG,
    MaterialColor? offWhite,
    MaterialColor? text,
    MaterialColor? darkText,
    MaterialColor? lightModeGray,
    MaterialColor? black,
    MaterialColor? darkBorder,
    MaterialColor? successSecondary,
    MaterialColor? accent,
  }) {
    return AppThemeColorsExtension(
      primary: primary ?? this.primary,
      white: white ?? this.white,
      disable: disable ?? this.disable,
      button: button ?? this.button,
      darkBlueBG: darkBlueBG ?? this.darkBlueBG,
      offWhite: offWhite ?? this.offWhite,
      text: text ?? this.text,
      darkText: darkText ?? this.darkText,
      lightModeGray: lightModeGray ?? this.lightModeGray,
      black: black ?? this.black,
      darkBorder: darkBorder ?? this.darkBorder,
      successSecondary: successSecondary ?? this.successSecondary,
      accent: accent ?? this.accent,
      gray: gray ?? this.gray,
      success: success ?? this.success,
      error: error ?? this.error,
    );
  }

  @override
  ThemeExtension<AppThemeColorsExtension> lerp(
    ThemeExtension<AppThemeColorsExtension>? other,
    double t,
  ) {
    if (other is! AppThemeColorsExtension) return this;
    return AppThemeColorsExtension(
      primary: primary.lerp(other.primary, t),
      error: error.lerp(other.error, t),
      success: success.lerp(other.success, t),
      white: white.lerp(other.white, t),
      text: text.lerp(other.text, t),
      darkText: darkText.lerp(other.darkText, t),
      lightModeGray: lightModeGray.lerp(other.lightModeGray, t),
      black: black.lerp(other.black, t),
      darkBorder: darkBorder.lerp(other.darkBorder, t),
      successSecondary: successSecondary.lerp(other.successSecondary, t),
      accent: accent.lerp(other.accent, t),
      gray: gray.lerp(other.gray, t),
      disable: disable.lerp(other.disable, t),
      button: button.lerp(other.button, t),
      darkBlueBG: darkBlueBG.lerp(other.darkBlueBG, t),
      offWhite: offWhite.lerp(other.offWhite, t),
    );
  }
}

extension on MaterialColor {
  MaterialColor lerp(MaterialColor color, double t) {
    return MaterialColor(
      400,
      {
        50: Color.lerp(this[50], color[50], t) ?? this,
        for (int shade = 100; shade <= 900; shade += 100)
          shade: Color.lerp(this[shade], color[shade], t) ?? this,
      },
    );
  }
}
