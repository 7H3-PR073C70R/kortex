import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/themes/theme_state.dart';

export 'enums/theme_preset.dart';
export 'theme_cubit.dart';
export 'theme_state.dart';

/// Optional [ChangeNotifier] adapter for widgets using Provider.
class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier(this._themeCubit) {
    _themeCubit.stream.listen((_) => notifyListeners());
  }

  final ThemeCubit _themeCubit;

  ThemeState get state => _themeCubit.state;
  ThemeMode get themeMode => state.themeMode;
  ThemePreset get preset => state.preset;
  Color? get customAccentColor => state.customAccentColor;

  Future<void> setThemeMode(ThemeMode mode) => _themeCubit.setThemeMode(mode);
  Future<void> setThemePreset(ThemePreset preset) =>
      _themeCubit.setThemePreset(preset);
  Future<void> setCustomAccentColor(Color? color) =>
      _themeCubit.setCustomAccentColor(color);
}
