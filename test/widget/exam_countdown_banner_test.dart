import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
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
  group('ExamCountdownBanner Widget Test Suite', () {
    late MockPlannerRepository mockRepository;
    late CramPlannerCubit cubit;

    final tExam = ExamEventEntity(
      id: 'exam-waec-physics',
      userId: 'usr-1',
      examName: 'WAEC Physics',
      targetDate: DateTime.now().add(const Duration(days: 18)),
      subjectTrack: 'WAEC',
      totalCardsCount: 180,
      dailyTarget: 10,
    );

    setUp(() {
      mockRepository = MockPlannerRepository();
      cubit = CramPlannerCubit(plannerRepository: mockRepository);
    });

    tearDown(() async {
      await cubit.close();
    });

    testWidgets('renders empty state prompt to add exam when no exams exist', (
      tester,
    ) async {
      when(
        () => mockRepository.getActiveExams(),
      ).thenAnswer((_) async => const Right([]));

      await tester.pumpWidget(
        createTestApp(
          BlocProvider<CramPlannerCubit>.value(
            value: cubit,
            child: const ExamCountdownBanner(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.alarm_add_rounded), findsOneWidget);
    });

    testWidgets(
      'renders live countdown and dynamic daily target pace when exam exists',
      (tester) async {
        when(
          () => mockRepository.getActiveExams(),
        ).thenAnswer((_) async => Right([tExam]));

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
        expect(find.textContaining('WAEC Physics'), findsOneWidget);
        expect(find.textContaining('WAEC Track'), findsOneWidget);
        expect(find.byIcon(Icons.auto_graph_rounded), findsOneWidget);
      },
    );
  });
}
