import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_missing_questions_sheet.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestWidget({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('QuizDuelMissingQuestionsSheet Widget Tests', () {
    testWidgets('renders title, explanations, and guidance options', (
      tester,
    ) async {
      var retryClicked = false;

      await tester.pumpWidget(
        createTestWidget(
          child: QuizDuelMissingQuestionsSheet(
            subject: 'Corporate Law',
            onRetry: () {
              retryClicked = true;
            },
          ),
        ),
      );

      // Verify header and subject
      expect(find.text('No Questions for Corporate Law'), findsOneWidget);
      expect(
        find.text(
          "We couldn't find any saved past questions or flashcards for Corporate Law on your device.",
        ),
        findsOneWidget,
      );

      // Verify two guidance cards
      expect(find.text('Connect to the Internet'), findsOneWidget);
      expect(find.text('Create a Flashcard Deck'), findsOneWidget);

      // Verify buttons
      expect(
        find.text('Create Study Deck for Corporate Law'),
        findsOneWidget,
      );
      expect(find.text('Try Again (Online)'), findsOneWidget);
      expect(find.text('Choose Another Subject'), findsOneWidget);

      // Tap Try Again
      final tryAgainFinder = find.text('Try Again (Online)');
      await tester.ensureVisible(tryAgainFinder);
      await tester.pumpAndSettle();
      await tester.tap(tryAgainFinder);
      await tester.pumpAndSettle();

      expect(retryClicked, isTrue);
    });
  });
}
