import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/add_past_question_modal_sheet.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Add Past Question Presentation Widgets Test Suite', () {
    testWidgets('AddQuestionYearSelector renders recent years and custom input', (
      tester,
    ) async {
      final selectedYear = ValueNotifier<int>(2025);
      final isCustomYear = ValueNotifier<bool>(false);
      final customYearController = TextEditingController();

      await tester.pumpWidget(
        createTestApp(
          AddQuestionYearSelector(
            selectedYear: selectedYear,
            isCustomYear: isCustomYear,
            customYearController: customYearController,
          ),
        ),
      );

      expect(find.text('Examination Year'), findsOneWidget);
      expect(find.text('Other'), findsOneWidget);

      await tester.tap(find.text('Other'));
      await tester.pump();
      expect(isCustomYear.value, isTrue);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('AddQuestionAiUploadView renders upload area and preview questions', (
      tester,
    ) async {
      final pickedFile = ValueNotifier(null);
      const testQuestion = PastQuestionEntity(
        id: 'q1',
        examType: ExamCategory.waec,
        subject: 'Biology',
        year: 2024,
        questionNumber: 1,
        prompt: 'What organelle is the powerhouse of the cell?',
        options: ['A. Ribosome', 'B. Mitochondria'],
        correctOptionIndex: 1,
        correctOptionLabel: 'B',
        explanation: 'Mitochondria produces ATP.',
        topic: 'Cell Biology',
      );

      await tester.pumpWidget(
        createTestApp(
          AddQuestionAiUploadView(
            pickedFile: pickedFile,
            isCalibrating: false,
            calibrationProgress: 0,
            calibrationStatus: '',
            calibratedQuestions: const [testQuestion],
            onPickFile: () {},
            onExecuteCalibration: () {},
            onSaveCalibrated: () {},
            isSubmitting: false,
            courseCode: 'BIO101',
          ),
        ),
      );

      expect(find.text('Upload Past Paper (PDF, Images, TXT)'), findsOneWidget);
      expect(find.text('Extracted 1 Questions (1 MCQ, 0 Theory)'), findsOneWidget);
      expect(
        find.text('What organelle is the powerhouse of the cell?'),
        findsOneWidget,
      );
      expect(find.text('Correct: B'), findsOneWidget);
      expect(find.text('Save 1 Questions to BIO101'), findsOneWidget);
    });

    testWidgets('AddQuestionManualFormView renders MCQ form and toggles theory mode', (
      tester,
    ) async {
      final isTheoryMode = ValueNotifier<bool>(false);
      final promptController = TextEditingController();
      final optionAController = TextEditingController();
      final optionBController = TextEditingController();
      final optionCController = TextEditingController();
      final optionDController = TextEditingController();
      final correctOptionLabel = ValueNotifier<String>('A');
      final explanationController = TextEditingController();
      final topicController = TextEditingController();
      final attachedImagePath = ValueNotifier<String?>(null);

      await tester.pumpWidget(
        createTestApp(
          AddQuestionManualFormView(
            isTheoryMode: isTheoryMode,
            promptController: promptController,
            optionAController: optionAController,
            optionBController: optionBController,
            optionCController: optionCController,
            optionDController: optionDController,
            correctOptionLabel: correctOptionLabel,
            explanationController: explanationController,
            topicController: topicController,
            attachedImagePath: attachedImagePath,
            onSaveQuestion: (_) {},
            isSubmitting: false,
            courseCode: 'CHM101',
            courseTitle: 'General Chemistry',
            courseId: 'c_chm',
            mappedSubject: 'Chemistry',
            examCategory: ExamCategory.waec,
            effectiveYear: 2025,
          ),
        ),
      );

      expect(find.text('Multiple Choice (MCQ)'), findsOneWidget);
      expect(find.text('Theory / Essay'), findsOneWidget);
      expect(find.text('Option A'), findsOneWidget);
      expect(find.text('Option B'), findsOneWidget);

      await tester.tap(find.text('Theory / Essay'));
      await tester.pump();
      expect(isTheoryMode.value, isTrue);
      expect(find.text('Option A'), findsNothing);
    });

    testWidgets('AddPastQuestionModalSheet renders modal header and tab bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          const AddPastQuestionModalSheet(
            courseId: 'c1',
            courseCode: 'MTH101',
            courseTitle: 'Calculus I',
            mappedSubject: 'Mathematics',
            examCategory: ExamCategory.waec,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Add Course Past Question'), findsOneWidget);
      expect(find.text('MTH101 • Calculus I'), findsOneWidget);
      expect(find.text('AI Document Upload'), findsOneWidget);
      expect(find.text('Manual Form Entry'), findsOneWidget);
    });
  });
}
