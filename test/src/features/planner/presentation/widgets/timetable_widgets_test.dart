import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_delete_dialog.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_empty_state.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_filter_bar.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_hero_countdown_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_ical_exporter.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_notification_preferences_card.dart';
import 'package:kortex/src/features/planner/presentation/widgets/timetable/exam_timetable_row_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

void main() {
  final tExam = ExamEventEntity(
    id: 'exam-1',
    userId: 'usr-1',
    examName: 'JAMB Mathematics',
    targetDate: DateTime.now().add(const Duration(days: 10)),
    subjectTrack: 'JAMB',
    totalCardsCount: 120,
    dailyTarget: 10,
    assessmentType: AssessmentType.quiz,
    weightPercent: 0.4,
  );

  Widget buildTestApp({required Widget child}) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('Timetable Widgets Modular Test Suite', () {
    testWidgets('ExamTimetableEmptyState renders message and button', (tester) async {
      await tester.pumpWidget(
        buildTestApp(child: const ExamTimetableEmptyState()),
      );

      expect(find.text('No Exams Scheduled Yet'), findsOneWidget);
      expect(find.text('Add First Exam'), findsOneWidget);
    });

    testWidgets('ExamTimetableFilterBar toggles filter chips and notifies', (tester) async {
      AssessmentType? selectedType;
      var showCompleted = false;

      await tester.pumpWidget(
        buildTestApp(
          child: ExamTimetableFilterBar(
            allExams: [tExam],
            selectedFilterType: null,
            showCompletedOnly: false,
            onFilterChanged: ({
              required selectedFilterType,
              required showCompletedOnly,
            }) {
              selectedType = selectedFilterType;
              showCompleted = showCompletedOnly;
            },
          ),
        ),
      );

      expect(find.byType(ChoiceChip), findsWidgets);
      await tester.tap(find.textContaining('Quizzes').first);
      expect(selectedType, equals(AssessmentType.quiz));
      expect(showCompleted, isFalse);
    });

    testWidgets('ExamTimetableHeroCountdownCard renders digits and name', (tester) async {
      await tester.pumpWidget(
        buildTestApp(child: ExamTimetableHeroCountdownCard(exam: tExam)),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('JAMB Mathematics'), findsOneWidget);
      expect(find.text('DAYS'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);
      expect(find.text('MINUTES'), findsOneWidget);
    });

    testWidgets('ExamTimetableRowCard triggers interaction callbacks', (tester) async {
      var selected = false;
      var edited = false;
      var deleted = false;
      var primaryActioned = false;

      await tester.pumpWidget(
        buildTestApp(
          child: ExamTimetableRowCard(
            exam: tExam,
            index: 0,
            isSelected: true,
            calculator: const CramWorkloadCalculator(),
            onSelect: () => selected = true,
            onEdit: () => edited = true,
            onDelete: () => deleted = true,
            onPrimaryAction: () => primaryActioned = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('JAMB Mathematics'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.edit_outlined));
      expect(edited, isTrue);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      expect(deleted, isTrue);

      await tester.tap(find.byType(OutlinedButton));
      expect(primaryActioned, isTrue);

      await tester.tap(find.byIcon(Icons.check));
      expect(selected, isTrue);
    });

    testWidgets('ExamTimetableNotificationPreferencesCard switches preferences', (tester) async {
      var dailyChanged = false;
      var milestoneChanged = false;

      await tester.pumpWidget(
        buildTestApp(
          child: ExamTimetableNotificationPreferencesCard(
            dailyReminderEnabled: true,
            milestoneAlertsEnabled: false,
            onDailyReminderChanged: (val) => dailyChanged = val,
            onMilestoneAlertsChanged: (val) => milestoneChanged = val,
          ),
        ),
      );

      expect(find.text('Timetable & Study Alerts'), findsOneWidget);

      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(2));

      await tester.tap(switches.first);
      expect(dailyChanged, isFalse);

      await tester.tap(switches.last);
      expect(milestoneChanged, isTrue);
    });

    testWidgets('ExamTimetableDeleteDialog displays modal with actions', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ExamTimetableDeleteDialog.show(context, tExam),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Assessment Countdown?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Assessment Countdown?'), findsNothing);
    });

    testWidgets('ExamTimetableIcalExporter formats iCal to clipboard without crashing', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ExamTimetableIcalExporter.exportToClipboard(context, [tExam]),
              child: const Text('Export'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();
      expect(find.textContaining('iCal timetable'), findsOneWidget);
    });
  });
}
