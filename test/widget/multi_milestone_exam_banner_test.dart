import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/widgets/exam_countdown_banner.dart';
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
  group('Multi-Milestone ExamCountdownBanner Widget Suite', () {
    late MockPlannerRepository mockRepository;
    late CramPlannerCubit cubit;

    final tQuiz = ExamEventEntity(
      id: 'quiz-mth-1',
      userId: 'usr-1',
      examName: 'MTH 101 Quiz 1',
      targetDate: DateTime.now().add(const Duration(days: 2)),
      subjectTrack: 'MTH 101',
      assessmentType: AssessmentType.quiz,
      scopedDeckIds: const ['deck-limits'],
      totalCardsCount: 30,
      dailyTarget: 15,
    );

    final tFinal = ExamEventEntity(
      id: 'final-phy-1',
      userId: 'usr-1',
      examName: 'PHY 102 Final Exam',
      targetDate: DateTime.now().add(const Duration(days: 45)),
      subjectTrack: 'PHY 102',
      totalCardsCount: 300,
      dailyTarget: 7,
    );

    setUp(() {
      mockRepository = MockPlannerRepository();
      cubit = CramPlannerCubit(plannerRepository: mockRepository);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets(
      'renders horizontal milestone carousel when multiple assessments exist',
      (tester) async {
        when(
          () => mockRepository.getActiveExams(),
        ).thenAnswer((_) async => Right([tQuiz, tFinal]));

        await cubit.loadExams();

        await tester.pumpWidget(
          createTestApp(
            BlocProvider<CramPlannerCubit>.value(
              value: cubit,
              child: const ExamCountdownBanner(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Expect both milestones to appear in the horizontal pill strip
        expect(find.text('MTH 101 Quiz 1'), findsOneWidget); // pill text
        expect(find.textContaining('MTH 101 Quiz 1'), findsNWidgets(2)); // pill + headline
        expect(find.text('PHY 102 Final Exam'), findsOneWidget); // in pill strip

        // For quiz, primary CTA should be Practice Scoped Cards
        expect(find.text('Practice Scoped Cards'), findsOneWidget);

        // Tap the second milestone pill in the strip
        await tester.tap(find.text('PHY 102 Final Exam'));
        await tester.pumpAndSettle();

        // Cubit should switch active milestone to the final exam
        expect(cubit.state.selectedExam?.id, equals('final-phy-1'));

        // Primary CTA now updates to Open Mock Lobby
        expect(find.text('Open Mock Lobby'), findsOneWidget);
      },
    );

    testWidgets(
      'renders consolidated daily capacity bar and grade weight badges',
      (tester) async {
        final examWithTopics = ExamEventEntity(
          id: 'exam-topics',
          userId: 'usr-1',
          examName: 'CHM 111 Class Test',
          targetDate: DateTime.now().add(const Duration(days: 3)),
          subjectTrack: 'CHM 111',
          assessmentType: AssessmentType.classTest,
          scopedTopics: const ['Stoichiometry', 'Thermodynamics'],
          totalCardsCount: 60,
        );

        when(
          () => mockRepository.getActiveExams(),
        ).thenAnswer((_) async => Right([examWithTopics, tFinal]));

        await cubit.loadExams();

        await tester.pumpWidget(
          createTestApp(
            BlocProvider<CramPlannerCubit>.value(
              value: cubit,
              child: const ExamCountdownBanner(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Consolidated capacity bar should be displayed because there are 2 exams
        expect(find.textContaining('Combined Today:'), findsOneWidget);

        // Scoped topics chips should be displayed
        expect(find.textContaining('Stoichiometry'), findsOneWidget);
        expect(find.textContaining('Thermodynamics'), findsOneWidget);

        // Weight badge should be displayed
        expect(find.text('20% Weight'), findsOneWidget);
      },
    );

    testWidgets(
      'renders sub-daily countdown format for imminent assessment (< 24h)',
      (tester) async {
        final imminentExam = ExamEventEntity(
          id: 'exam-imminent',
          userId: 'usr-1',
          examName: 'Emergency Cram Quiz',
          targetDate: DateTime.now().add(const Duration(hours: 8, minutes: 30)),
          subjectTrack: 'MTH 101',
          assessmentType: AssessmentType.quiz,
          totalCardsCount: 30,
          dailyTarget: 30,
        );

        when(
          () => mockRepository.getActiveExams(),
        ).thenAnswer((_) async => Right([imminentExam]));

        await cubit.loadExams();

        await tester.pumpWidget(
          createTestApp(
            BlocProvider<CramPlannerCubit>.value(
              value: cubit,
              child: const ExamCountdownBanner(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Sub-daily countdown should show hours and minutes left, e.g. "8h 29m left" or "8h 30m left"
        expect(find.textContaining('8h'), findsOneWidget);
        expect(find.textContaining('left'), findsWidgets);
      },
    );
  });
}
