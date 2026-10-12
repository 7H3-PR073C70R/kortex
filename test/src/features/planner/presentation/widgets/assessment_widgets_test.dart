import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_action_buttons.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_date_time_pickers_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_decks_selector_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_name_field.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_searchable_course_dropdown.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_topics_tagging_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_type_selector.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_weight_selector_section.dart';
import 'package:kortex/src/features/planner/presentation/widgets/assessment/assessment_workload_calculation_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, _) => MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  group('Assessment Sub-Widgets Tests', () {
    testWidgets('AssessmentTypeSelector renders all types and triggers onTypeChanged',
        (tester) async {
      AssessmentType? selected;
      await tester.pumpWidget(
        createTestWidget(
          AssessmentTypeSelector(
            selectedType: AssessmentType.finalExam,
            onTypeChanged: (type) => selected = type,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Final Exam'), findsOneWidget);
      expect(find.text('Quiz'), findsOneWidget);
      expect(find.text('Mid-Term'), findsOneWidget);

      await tester.tap(find.text('Quiz'));
      await tester.pumpAndSettle();

      expect(selected, AssessmentType.quiz);
    });

    testWidgets('AssessmentNameField displays label and validates input',
        (tester) async {
      final controller = TextEditingController();
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        createTestWidget(
          Form(
            key: formKey,
            child: AssessmentNameField(
              controller: controller,
              selectedType: AssessmentType.midterm,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsOneWidget);

      final isValid = formKey.currentState!.validate();
      await tester.pumpAndSettle();
      expect(isValid, isFalse);

      controller.text = 'Midterm Thermodynamics';
      final isNowValid = formKey.currentState!.validate();
      expect(isNowValid, isTrue);
    });

    testWidgets('AssessmentDecksSelectorSection renders course decks and toggles selection',
        (tester) async {
      final decks = <DeckEntity>[
        const DeckEntity(
          id: 'deck-1',
          title: 'Thermodynamics Formulas',
          subject: 'MECH 301',
          totalCards: 45,
          dueCards: 5,
          masteryRate: 0.8,
          category: 'Engineering',
        ),
        const DeckEntity(
          id: 'deck-2',
          title: 'Fluid Dynamics',
          subject: 'MECH 301',
          totalCards: 30,
          dueCards: 10,
          masteryRate: 0.6,
          category: 'Engineering',
        ),
      ];

      var selectAllCalled = false;
      var clearAllCalled = false;
      String? toggledDeckId;

      await tester.pumpWidget(
        createTestWidget(
          AssessmentDecksSelectorSection(
            courseDecks: decks,
            selectedDeckIds: const {'deck-1'},
            onToggleDeck: (id) => toggledDeckId = id,
            onSelectAll: () => selectAllCalled = true,
            onClearAll: () => clearAllCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thermodynamics Formulas (45)'), findsOneWidget);
      expect(find.text('Fluid Dynamics (30)'), findsOneWidget);

      await tester.tap(find.text('Select All'));
      expect(selectAllCalled, isTrue);

      await tester.tap(find.text('Clear'));
      expect(clearAllCalled, isTrue);

      await tester.tap(find.text('Fluid Dynamics (30)'));
      expect(toggledDeckId, 'deck-2');
    });

    testWidgets('AssessmentTopicsTaggingSection renders topics and triggers callbacks',
        (tester) async {
      final topicController = TextEditingController();
      var addCalled = false;
      String? removedTopic;

      await tester.pumpWidget(
        createTestWidget(
          AssessmentTopicsTaggingSection(
            topicController: topicController,
            scopedTopics: const ['Entropy', 'Carnot Engine'],
            onAddTopic: () => addCalled = true,
            onRemoveTopic: (t) => removedTopic = t,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Entropy'), findsOneWidget);
      expect(find.text('Carnot Engine'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      expect(addCalled, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      expect(removedTopic, 'Entropy');
    });

    testWidgets('AssessmentWorkloadCalculationCard renders calculated totals and daily target',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const AssessmentWorkloadCalculationCard(
            isCalculatingWorkload: false,
            totalWorkload: 150,
            deckCardsCount: 100,
            scopedDecksCount: 2,
            pastQuestionsCount: 50,
            dailyTarget: 15,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('150'), findsWidgets);
      expect(find.textContaining('100 flashcards'), findsOneWidget);
      expect(find.textContaining('50 practice questions'), findsOneWidget);
      expect(find.text('~15 items / day'), findsOneWidget);
    });

    testWidgets('AssessmentDateTimePickersSection renders formatted values and responds to taps',
        (tester) async {
      var datePicked = false;
      var timePicked = false;

      await tester.pumpWidget(
        createTestWidget(
          AssessmentDateTimePickersSection(
            selectedDate: DateTime(2026, 12, 15),
            selectedTime: const TimeOfDay(hour: 14, minute: 30),
            onPickDate: () => datePicked = true,
            onPickTime: () => timePicked = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tue, 15 Dec 2026'), findsOneWidget);
      expect(find.textContaining('2:30'), findsOneWidget);

      await tester.tap(find.text('Tue, 15 Dec 2026'));
      expect(datePicked, isTrue);

      await tester.tap(find.textContaining('2:30'));
      expect(timePicked, isTrue);
    });

    testWidgets('AssessmentWeightSelectorSection selects weight percentage',
        (tester) async {
      double? selectedWeight;

      await tester.pumpWidget(
        createTestWidget(
          AssessmentWeightSelectorSection(
            selectedWeightPercent: 0.30,
            onWeightSelected: (w) => selectedWeight = w,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('30%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      await tester.tap(find.text('50%'));
      expect(selectedWeight, 0.50);
    });

    testWidgets('AssessmentActionButtons handles cancel and submit',
        (tester) async {
      var cancelled = false;
      var submitted = false;

      await tester.pumpWidget(
        createTestWidget(
          AssessmentActionButtons(
            isEditing: false,
            isEnabled: true,
            onCancel: () => cancelled = true,
            onSubmit: () => submitted = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Exam Countdown'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      expect(cancelled, isTrue);

      await tester.tap(find.text('Save Exam Countdown'));
      expect(submitted, isTrue);
    });

    testWidgets('AssessmentSearchableCourseDropdown expands and selects a course',
        (tester) async {
      final courses = <CuratedCourseModel>[
        const CuratedCourseModel(
          id: 'course-1',
          courseCode: 'MECH 301',
          title: 'Advanced Thermodynamics',
          department: 'Engineering',
          totalMaterials: 12,
          hasActivePastPapers: true,
          iconName: 'school',
          colorHex: '#4F46E5',
        ),
        const CuratedCourseModel(
          id: 'course-2',
          courseCode: 'ELEC 202',
          title: 'Circuits & Systems',
          department: 'Engineering',
          totalMaterials: 8,
          hasActivePastPapers: false,
          iconName: 'bolt',
          colorHex: '#06B6D4',
        ),
      ];

      CuratedCourseModel? selectedCourse;

      await tester.pumpWidget(
        createTestWidget(
          AssessmentSearchableCourseDropdown(
            courses: courses,
            selectedCourse: courses.first,
            onCourseSelected: (c) => selectedCourse = c,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MECH 301 - Advanced Thermodynamics'), findsOneWidget);

      // Expand dropdown
      await tester.tap(find.text('MECH 301 - Advanced Thermodynamics'));
      await tester.pumpAndSettle();

      expect(find.text('Circuits & Systems'), findsOneWidget);

      // Select course-2
      await tester.tap(find.text('Circuits & Systems'));
      await tester.pumpAndSettle();

      expect(selectedCourse?.courseCode, 'ELEC 202');
    });
  });
}
