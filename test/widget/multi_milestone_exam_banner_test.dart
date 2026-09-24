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
  });
}
