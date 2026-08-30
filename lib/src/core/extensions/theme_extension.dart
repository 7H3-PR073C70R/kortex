import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';

extension ThemeExtension on BuildContext {
  /// Active [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// Material [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Custom [TypographyThemeExtension] providing tailored typography tokens.
  TypographyThemeExtension get textTheme =>
      Theme.of(this).extension<TypographyThemeExtension>()!;

  /// Alias for [textTheme].
  TypographyThemeExtension get typography => textTheme;

  /// Custom [AppThemeColorsExtension] providing STEM & active-recall tokens.
  AppThemeColorsExtension get colors =>
      Theme.of(this).extension<AppThemeColorsExtension>()!;

  /// Alias for [colors].
  AppThemeColorsExtension get appColors => colors;

  /// Whether current theme is dark brightness.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
