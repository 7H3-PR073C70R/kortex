import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/themes/theme_cubit.dart';
import 'package:kortex/src/features/profile/presentation/pages/app_preferences_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockLocalStorageService mockStorage;
  late ThemeCubit themeCubit;

  setUp(() {
    mockStorage = MockLocalStorageService();
    when(
      () => mockStorage.getPreference(key: any(named: 'key')),
    ).thenReturn(null);
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

  Widget createTestWidget() {
    return BlocProvider<ThemeCubit>.value(
      value: themeCubit,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: const AppPreferencesPage(),
      ),
    );
  }

  group('AppPreferencesPage Test Suite', () {
    testWidgets('renders all 3 theme options: System, Light, and Dark', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Color Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
      expect(find.byIcon(Icons.brightness_auto_rounded), findsOneWidget);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);
    });

    testWidgets('tapping System switches to ThemeMode.system', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // First tap Dark
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(themeCubit.state.themeMode, equals(ThemeMode.dark));

      // Tap System
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(themeCubit.state.themeMode, equals(ThemeMode.system));
    });

    testWidgets('tapping Light switches to ThemeMode.light', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(themeCubit.state.themeMode, equals(ThemeMode.light));
    });

    testWidgets('renders haptics, sfx, and study reminder switches', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Haptic Feedback'), findsOneWidget);
      expect(find.text('Sound Effects (SFX)'), findsOneWidget);
      expect(find.text('Daily Study Reminder'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(3));
    });
  });
}
