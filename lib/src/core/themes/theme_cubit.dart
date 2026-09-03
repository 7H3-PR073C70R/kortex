import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';
import 'package:kortex/src/core/themes/theme_state.dart';

/// Business logic component managing ThemeMode, Presets, and Custom Accents.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({required LocalStorageService storageService})
    : _storageService = storageService,
      super(const ThemeState()) {
    _loadFromStorage();
  }

  final LocalStorageService _storageService;

  void _loadFromStorage() {
    try {
      final savedMode = _storageService.getPreference(key: PrefKeys.themeMode);
      final savedPreset = _storageService.getPreference(
        key: PrefKeys.themePreset,
      );
      final savedAccent = _storageService.getPreference(
        key: PrefKeys.themeCustomAccent,
      );

      var mode = ThemeMode.system;
      if (savedMode != null) {
        mode = ThemeMode.values.firstWhere(
          (e) => e.name == savedMode,
          orElse: () => ThemeMode.system,
        );
      }

      var preset = ThemePreset.slateDark;
      if (savedPreset != null) {
        preset = ThemePreset.values.firstWhere(
          (e) => e.name == savedPreset,
          orElse: () => ThemePreset.slateDark,
        );
      }

      Color? accent;
      if (savedAccent != null) {
        final value = int.tryParse(savedAccent);
        if (value != null) {
          accent = Color(value);
        }
      }

      emit(
        state.copyWith(
          themeMode: mode,
          preset: preset,
          customAccentColor: () => accent,
        ),
      );
    } on Object {
      // Keep default theme state on storage read error
    }
  }

  /// Update active [ThemeMode].
  Future<void> setThemeMode(ThemeMode mode) async {
    emit(state.copyWith(themeMode: mode));
    await _storageService.savePreference(
      key: PrefKeys.themeMode,
      data: mode.name,
    );
  }

  /// Update active [ThemePreset].
  Future<void> setThemePreset(ThemePreset preset) async {
    emit(state.copyWith(preset: preset));
    await _storageService.savePreference(
      key: PrefKeys.themePreset,
      data: preset.name,
    );
  }

  /// Set or clear a custom seed accent color.
  Future<void> setCustomAccentColor(Color? color) async {
    emit(state.copyWith(customAccentColor: () => color));
    if (color != null) {
      await _storageService.savePreference(
        key: PrefKeys.themeCustomAccent,
        data: color.toARGB32().toString(),
      );
    } else {
      await _storageService.deletePreference(key: PrefKeys.themeCustomAccent);
    }
  }
}
