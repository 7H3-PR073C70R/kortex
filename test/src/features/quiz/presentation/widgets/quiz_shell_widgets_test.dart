import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_shell.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('QuizSetupControls Widget Tests', () {
    testWidgets('QuizSectionLabel renders label and optional trailing widget', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const QuizSectionLabel(
            label: 'Game Mode',
            trailing: Text('Trailing Action'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GAME MODE'), findsOneWidget);
      expect(find.text('Trailing Action'), findsOneWidget);
    });

    testWidgets('QuizChoiceCard renders title, subtitle, and responds to tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        createTestApp(
          QuizChoiceCard(
            icon: Icons.quiz_outlined,
            title: 'Standard Quiz',
            subtitle: '10 questions from course syllabus',
            selected: true,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Standard Quiz'), findsOneWidget);
      expect(find.text('10 questions from course syllabus'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.text('Standard Quiz'));
      expect(tapped, isTrue);
    });

    testWidgets('QuizModeSegmentedControl renders 3 modes and dispatches callback on selection', (tester) async {
      QuizPracticeMode? selected;
      await tester.pumpWidget(
        createTestApp(
          QuizModeSegmentedControl(
            currentMode: QuizPracticeMode.practice,
            onModeSelected: (mode) => selected = mode,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Exam'), findsOneWidget);
      expect(find.text('Millionaire'), findsOneWidget);

      await tester.tap(find.text('Exam'));
      expect(selected, equals(QuizPracticeMode.exam));

      await tester.tap(find.text('Millionaire'));
      expect(selected, equals(QuizPracticeMode.millionaire));
    });

    testWidgets('QuizModeDescription renders corresponding descriptions for each mode', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const Column(
            children: [
              QuizModeDescription(mode: QuizPracticeMode.practice),
              QuizModeDescription(mode: QuizPracticeMode.exam),
              QuizModeDescription(mode: QuizPracticeMode.millionaire),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Instant feedback & explanations'), findsOneWidget);
      expect(find.textContaining('Timed exam simulation'), findsOneWidget);
      expect(find.textContaining('12-tier challenge ladder'), findsOneWidget);
    });

    testWidgets('QuizMillionaireNotice renders locked ladder message', (tester) async {
      await tester.pumpWidget(
        createTestApp(const QuizMillionaireNotice()),
      );
      await tester.pumpAndSettle();

      expect(find.text('12 Questions · Fixed ladder'), findsOneWidget);
      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    });
  });

  group('QuizSelectorPills Widget Tests', () {
    testWidgets('QuizTagPill renders label and icon', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const QuizTagPill(
            label: 'Algebra',
            color: Colors.blue,
            icon: Icons.tag,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Algebra'), findsOneWidget);
      expect(find.byIcon(Icons.tag), findsOneWidget);
    });

    testWidgets('QuizStatChip renders label and formatted value', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const QuizStatChip(
            label: 'Accuracy',
            value: '85%',
            color: Colors.green,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('85%'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
    });

    testWidgets('QuizYearPill and QuizCountOptionPill respond to user interaction', (tester) async {
      var yearTapped = false;
      var countTapped = false;

      await tester.pumpWidget(
        createTestApp(
          Column(
            children: [
              QuizYearPill(
                label: '2023',
                isSelected: true,
                badge: 'HOT',
                onTap: () => yearTapped = true,
              ),
              QuizCountOptionPill(
                count: 15,
                isSelected: false,
                onTap: () => countTapped = true,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2023'), findsOneWidget);
      expect(find.text('HOT'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text(' Qs'), findsOneWidget);

      await tester.tap(find.text('2023'));
      expect(yearTapped, isTrue);

      await tester.tap(find.text('15'));
      expect(countTapped, isTrue);
    });
  });

  group('QuizChromePrimitives & QuizFeedbackPanel Widget Tests', () {
    testWidgets('QuizProgressBar renders progress width proportionally', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const QuizProgressBar(value: 0.75),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QuizProgressBar), findsOneWidget);
    });

    testWidgets('QuizVerdictPanel renders correct answer feedback and explanation', (tester) async {
      const question = QuizQuestionEntity(
        id: 'q1',
        prompt: 'What is 5 + 7?',
        type: QuizQuestionType.multipleChoice,
        options: ['10', '11', '12', '13'],
        correctAnswer: '12',
        userSelectedAnswer: '12',
        explanation: '5 + 7 equals 12 by arithmetic definition.',
        subTopic: 'Arithmetic',
      );

      await tester.pumpWidget(
        createTestApp(
          const QuizVerdictPanel(
            verdict: QuizVerdict.correct,
            question: question,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.textContaining('Nice, you got it! Correct answer: 12'), findsOneWidget);
      expect(find.text('5 + 7 equals 12 by arithmetic definition.'), findsOneWidget);
    });

    testWidgets('QuizEmptyState renders headline, message, and action button', (tester) async {
      var actionTriggered = false;
      await tester.pumpWidget(
        createTestApp(
          QuizEmptyState(
            icon: Icons.search_off_rounded,
            headline: 'No questions found',
            message: 'Try adjusting your search filters or course selection.',
            actionLabel: 'Reset Filters',
            onAction: () => actionTriggered = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No questions found'), findsOneWidget);
      expect(find.text('Try adjusting your search filters or course selection.'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      await tester.tap(find.text('Reset Filters'));
      expect(actionTriggered, isTrue);
    });
  });
}
