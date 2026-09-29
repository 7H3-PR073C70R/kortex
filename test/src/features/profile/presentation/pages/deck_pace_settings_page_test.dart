import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/profile/presentation/pages/deck_pace_settings_page.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget createTestWidget() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const DeckPaceSettingsPage(),
    );
  }

  group('DeckPaceSettingsPage Widget Tests', () {
    testWidgets('renders pace presets title and options correctly', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Deck Study Pace'), findsOneWidget);
      expect(find.text('PACING PRESETS'), findsOneWidget);
      expect(find.text('Relaxed'), findsOneWidget);
      expect(find.text('Balanced'), findsOneWidget);
      expect(find.text('Intensive'), findsOneWidget);
    });
  });
}
