import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/presentation/pages/offline_flashcard_generation_page.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  group('OfflineFlashcardGenerationPage', () {
    testWidgets('does NOT render Cloud Online badge in AppBar', (
      tester,
    ) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, child) => MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const OfflineFlashcardGenerationPage(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cloud Online text or pill should not exist anywhere in the view
      expect(find.text('Cloud Online'), findsNothing);
      expect(find.textContaining('Cloud Online'), findsNothing);
    });
  });
}
