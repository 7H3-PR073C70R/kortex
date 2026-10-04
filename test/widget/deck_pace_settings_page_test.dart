import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/profile/presentation/pages/deck_pace_settings_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MockLocalStorageService mockStorage;

  setUp(() async {
    mockStorage = MockLocalStorageService();
    when(() => mockStorage.getPreference(key: any(named: 'key')))
        .thenReturn(null);
    when(() => mockStorage.savePreference(key: any(named: 'key'), data: any(named: 'data')))
        .thenAnswer((_) async => true);

    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(mockStorage);
  });

  tearDown(() async {
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  group('DeckPaceSettingsPage Widget Test Suite', () {
    testWidgets('renders title, pacing presets, and save button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const DeckPaceSettingsPage()));
      await tester.pump();

      expect(find.text('Deck Study Pace'), findsOneWidget);
      expect(find.text('Memory Spacing & Review Limits'), findsOneWidget);
      expect(find.text('PACING PRESETS'), findsOneWidget);
      expect(find.text('Relaxed'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('Intensive'), findsOneWidget);
      expect(find.text('Custom FSRS-6'), findsOneWidget);
      expect(find.text('Save & Sync Deck Pace'), findsOneWidget);
    });

    testWidgets('tapping Relaxed preset updates selection and target retention', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const DeckPaceSettingsPage()));
      await tester.pump();

      await tester.tap(find.text('Relaxed'));
      await tester.pump();

      expect(find.text('80%'), findsOneWidget);
    });

    testWidgets('tapping Save & Sync Deck Pace invokes storage save', (tester) async {
      tester.view.physicalSize = const Size(1080, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(const DeckPaceSettingsPage()));
      await tester.pump();

      final saveFinder = find.byKey(const Key('save_deck_pace_button'));
      expect(saveFinder, findsOneWidget);
      await tester.ensureVisible(saveFinder);
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      verify(() => mockStorage.savePreference(key: any(named: 'key'), data: any(named: 'data'))).called(1);
    });
  });
}
