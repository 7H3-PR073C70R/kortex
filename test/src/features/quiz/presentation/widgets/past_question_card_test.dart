import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/question_explanation_box.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/past_question_card/theory_model_answer_widget.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: child,
      ),
    ),
  );
}

void main() {
  group('PastQuestionCard Tests', () {
    const testMcq = PastQuestionEntity(
      id: 'q1',
      examType: ExamCategory.waec,
      subject: 'Physics',
      year: 2023,
      questionNumber: 4,
      prompt: 'What is the SI unit of electric current?',
      options: ['Volt', 'Ampere', 'Ohm', 'Watt'],
      correctOptionIndex: 1,
      correctOptionLabel: 'B',
      explanation: 'The SI unit of electric current is the ampere.',
      topic: 'Current Electricity',
    );

    const testTheory = PastQuestionEntity(
      id: 'q2',
      examType: ExamCategory.waec,
      subject: 'Chemistry',
      year: 2022,
      questionNumber: 1,
      prompt: 'State Charles law and give its mathematical equation.',
      options: [],
      correctOptionIndex: -1,
      correctOptionLabel: '',
      explanation: 'Volume is directly proportional to temperature at constant pressure.',
      topic: 'Gas Laws',
    );

    testWidgets('renders MCQ prompt, badges, and options correctly', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PastQuestionCard(
            question: testMcq,
            isInstantFeedback: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Physics • 2023 • Q4'), findsOneWidget);
      expect(find.text('Current Electricity'), findsOneWidget);
      expect(find.text('Discuss with Peers'), findsOneWidget);
      expect(find.text('Ask Syllabot AI'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('triggers onOptionSelected callback when option tapped', (tester) async {
      int? selectedIndex;
      await tester.pumpWidget(
        createTestApp(
          PastQuestionCard(
            question: testMcq,
            isInstantFeedback: true,
            onOptionSelected: (idx) => selectedIndex = idx,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on option B (index 1)
      await tester.tap(find.text('B'));
      expect(selectedIndex, equals(1));
    });

    testWidgets('triggers onBookmarkToggle callback when bookmark button tapped', (tester) async {
      var bookmarkToggled = false;
      await tester.pumpWidget(
        createTestApp(
          PastQuestionCard(
            question: testMcq,
            isInstantFeedback: true,
            onBookmarkToggle: () => bookmarkToggled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bookmarkFinder = find.byIcon(Icons.bookmark_outline_rounded);
      expect(bookmarkFinder, findsOneWidget);
      await tester.tap(bookmarkFinder);
      expect(bookmarkToggled, isTrue);
    });

    testWidgets('renders TheoryModelAnswerWidget when question is theory', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const PastQuestionCard(
            question: testTheory,
            isInstantFeedback: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Theory / Essay'), findsOneWidget);
      expect(find.byType(TheoryModelAnswerWidget), findsOneWidget);
      expect(find.text('Model Solution & Verified Answer'), findsOneWidget);
    });

    testWidgets('displays QuestionExplanationBox when answered with instant feedback', (tester) async {
      final answeredQuestion = testMcq.copyWith(
        userSelectedOptionIndex: 1,
      );

      await tester.pumpWidget(
        createTestApp(
          PastQuestionCard(
            question: answeredQuestion,
            isInstantFeedback: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuestionExplanationBox), findsOneWidget);
      expect(find.text('Explanation & Solution'), findsOneWidget);
    });
  });
}
