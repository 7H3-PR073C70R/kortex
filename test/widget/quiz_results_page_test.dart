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
      'renders score percentage, sub-topic weaknesses, and practice button',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            const QuizResultsPage(result: tResult),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('WAEC Thermodynamics Mock'), findsOneWidget);
        expect(find.text('Your Score: 80%'), findsOneWidget);
        expect(find.text('8 of 10 questions correct'), findsOneWidget);
        expect(find.text('Entropy & 2nd Law'), findsOneWidget);
        expect(find.text('Calorimetry'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
        expect(find.text('Practice Weak Flashcards'), findsOneWidget);
      },
    );
  });
}
