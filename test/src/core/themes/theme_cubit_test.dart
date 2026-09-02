import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/themes/enums/theme_preset.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockLocalStorageService mockStorage;
  late ThemeCubit themeCubit;

  setUp(() {
    mockStorage = MockLocalStorageService();
    when(() => mockStorage.getPreference(key: any(named: 'key')))
        .thenReturn(null);
    when(
      () => mockStorage.savePreference(
        key: any(named: 'key'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockStorage.deletePreference(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    themeCubit = ThemeCubit(storageService: mockStorage);
  });

  group('ThemeCubit', () {
    test('initial state is default ThemeState', () {
      expect(themeCubit.state.themeMode, equals(ThemeMode.system));
      expect(themeCubit.state.preset, equals(ThemePreset.slateDark));
      expect(themeCubit.state.customAccentColor, isNull);
    });

    test('setThemeMode updates state and saves to storage', () async {
      await themeCubit.setThemeMode(ThemeMode.dark);
      expect(themeCubit.state.themeMode, equals(ThemeMode.dark));
      verify(
        () => mockStorage.savePreference(
          key: PrefKeys.themeMode,
          data: 'dark',
        ),
      ).called(1);
    });

    test('setThemePreset updates state and saves to storage', () async {
      await themeCubit.setThemePreset(ThemePreset.midnightOled);
      expect(themeCubit.state.preset, equals(ThemePreset.midnightOled));
      verify(
        () => mockStorage.savePreference(
          key: PrefKeys.themePreset,
          data: 'midnightOled',
        ),
      ).called(1);
    });

    test('setCustomAccentColor updates state and storage', () async {
      const color = Color(0xFF10B981);
      await themeCubit.setCustomAccentColor(color);
      expect(themeCubit.state.customAccentColor, equals(color));
      verify(
        () => mockStorage.savePreference(
          key: PrefKeys.themeCustomAccent,
          data: color.toARGB32().toString(),
        ),
      ).called(1);

      await themeCubit.setCustomAccentColor(null);
      expect(themeCubit.state.customAccentColor, isNull);
      verify(
        () => mockStorage.deletePreference(key: PrefKeys.themeCustomAccent),
      ).called(1);
    });

    test('currentTheme resolves based on platform brightness', () {
      expect(
        themeCubit.state.currentTheme(Brightness.dark).brightness,
        equals(Brightness.dark),
      );
      expect(
        themeCubit.state.currentTheme(Brightness.light).brightness,
        equals(Brightness.light),
      );
    });
  });
}
