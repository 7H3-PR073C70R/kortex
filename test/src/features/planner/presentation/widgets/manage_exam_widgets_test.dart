import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/manage_exam_modal_sheet.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockPlannerRepository extends Mock implements PlannerRepository {}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('ManageExamModalSheet & Sub-widgets Test Suite', () {
    late MockPlannerRepository mockRepository;
    late CramPlannerCubit cubit;

    final exam1 = ExamEventEntity(
      id: 'exam-101',
      userId: 'usr-1',
      examName: 'MTH 101 Midterm',
      targetDate: DateTime.now().add(const Duration(days: 7)),
      subjectTrack: 'MTH 101',
      assessmentType: AssessmentType.midterm,
      scopedTopics: const ['Calculus', 'Limits'],
      totalCardsCount: 50,
      dailyTarget: 8,
    );

    final exam2 = ExamEventEntity(
      id: 'exam-102',
      userId: 'usr-1',
      examName: 'PHY 102 Quiz',
      targetDate: DateTime.now().add(const Duration(days: 14)),
      subjectTrack: 'PHY 102',
      assessmentType: AssessmentType.quiz,
      totalCardsCount: 30,
      dailyTarget: 5,
    );

    setUp(() {
      mockRepository = MockPlannerRepository();
      cubit = CramPlannerCubit(plannerRepository: mockRepository);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets('renders empty state when no exams match criteria', (tester) async {
      when(() => mockRepository.getActiveExams())
          .thenAnswer((_) async => const Right([]));

      await cubit.loadExams();

      await tester.pumpWidget(
        createTestApp(
          BlocProvider<CramPlannerCubit>.value(
            value: cubit,
            child: const ManageExamModalSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Active Assessment'), findsOneWidget);
    });

    testWidgets('renders active exam card, milestones list, and actions dock', (tester) async {
      when(() => mockRepository.getActiveExams())
          .thenAnswer((_) async => Right([exam1, exam2]));

      await cubit.loadExams();

      await tester.pumpWidget(
        createTestApp(
          BlocProvider<CramPlannerCubit>.value(
            value: cubit,
            child: const ManageExamModalSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Manage Academic Milestones'), findsOneWidget);
      expect(find.text('MTH 101 Midterm'), findsWidgets);
      expect(find.textContaining('MID-TERM • MTH 101'), findsOneWidget);
      expect(find.textContaining('Calculus, Limits'), findsOneWidget);
      expect(find.text('View Full Timetable & Pacing'), findsOneWidget);
      expect(find.text('Delete This Countdown'), findsOneWidget);
    });

    testWidgets('switching milestone in list triggers cubit selection', (tester) async {
      when(() => mockRepository.getActiveExams())
          .thenAnswer((_) async => Right([exam1, exam2]));

      await cubit.loadExams();

      await tester.pumpWidget(
        createTestApp(
          BlocProvider<CramPlannerCubit>.value(
            value: cubit,
            child: const ManageExamModalSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on PHY 102 Quiz in the switch list
      await tester.tap(find.text('PHY 102 Quiz'));
      await tester.pumpAndSettle();

      expect(cubit.state.selectedExam?.id, equals('exam-102'));
    });
  });
}
