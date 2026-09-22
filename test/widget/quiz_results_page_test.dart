import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/presentation/pages/quiz_results_page.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  group('QuizResultsPage Widget Test Suite', () {
    const tResult = QuizResultEntity(
      id: 'res-thermo-01',
      quizTitle: 'WAEC Thermodynamics Mock',
      totalQuestions: 10,
      correctAnswers: 8,
      durationSeconds: 150,
      weaknesses: [
        TopicWeakness(
          subTopic: 'Entropy & 2nd Law',
          totalQuestions: 4,
          correctCount: 2, // 50% => Weak
        ),
        TopicWeakness(
          subTopic: 'Calorimetry',
          totalQuestions: 6,
          correctCount: 6, // 100% => Strong
        ),
      ],
    );

    testWidgets(
      'renders score arc, sub-topic weaknesses, and the primary action',
      (tester) async {
        // This page is content-rich; use a tall surface so the score arc,
        // stats row, and topic breakdown all lay out on-stage.
        tester.view.physicalSize = const Size(1000, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          createTestApp(
            const QuizResultsPage(
              result: tResult,
              showCelebrationDialog: false,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('WAEC Thermodynamics Mock'), findsOneWidget);
        expect(find.text('80%'), findsOneWidget);
        expect(find.text('You scored 80%'), findsOneWidget);
        expect(find.text('8 of 10 questions correct'), findsOneWidget);
        expect(find.text('Entropy & 2nd Law'), findsOneWidget);
        expect(find.text('Calorimetry'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        // No question bodies were supplied, so the review action falls back
        // to the dashboard CTA.
        expect(find.text('Back to dashboard'), findsOneWidget);
      },
    );
  });
}
