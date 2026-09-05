import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';
import 'package:kortex/src/features/planner/domain/repositories/planner_repository.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_cubit.dart';
import 'package:kortex/src/features/planner/presentation/bloc/cram_planner_state.dart';
import 'package:mocktail/mocktail.dart';

class MockPlannerRepository extends Mock implements PlannerRepository {}

void main() {
  group('CramPlannerCubit Test Suite', () {
    late MockPlannerRepository mockRepository;
    late CramPlannerCubit cubit;

    final tExam = ExamEventEntity(
      id: 'exam-waec-1',
      userId: 'user-1',
      examName: 'WAEC Physics',
      targetDate: DateTime.now().add(const Duration(days: 20)),
      subjectTrack: 'WAEC',
      totalCardsCount: 200,
    );

    setUp(() {
      mockRepository = MockPlannerRepository();
      cubit = CramPlannerCubit(plannerRepository: mockRepository);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('initial state has initial status', () {
      expect(cubit.state.status, equals(CramPlannerStatus.initial));
    });

    blocTest<CramPlannerCubit, CramPlannerState>(
      'emits [loading, loaded] when loadExams succeeds with exams',
      build: () {
        when(
          () => mockRepository.getActiveExams(),
        ).thenAnswer((_) async => Right([tExam]));
        return cubit;
      },
      act: (cubit) => cubit.loadExams(),
      expect: () => [
        const CramPlannerState(status: CramPlannerStatus.loading),
        isA<CramPlannerState>()
            .having((s) => s.status, 'status', CramPlannerStatus.loaded)
            .having((s) => s.activeExams.length, 'exams length', 1)
            .having((s) => s.urgencyLevel, 'urgency', ExamUrgencyLevel.normal),
      ],
    );

    blocTest<CramPlannerCubit, CramPlannerState>(
      'emits [loading, error] when loadExams fails',
      build: () {
        when(() => mockRepository.getActiveExams()).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'DB Offline')),
        );
        return cubit;
      },
      act: (cubit) => cubit.loadExams(),
      expect: () => [
        const CramPlannerState(status: CramPlannerStatus.loading),
        const CramPlannerState(
          status: CramPlannerStatus.error,
          errorMessage: 'DB Offline',
        ),
      ],
    );

    blocTest<CramPlannerCubit, CramPlannerState>(
      'emits [loading, loaded] and removes exam when deleteExamCountdown succeeds',
      build: () {
        when(() => mockRepository.deleteExam(tExam.id)).thenAnswer(
          (_) async => const Right(null),
        );
        return cubit;
      },
      seed: () => CramPlannerState(
        status: CramPlannerStatus.loaded,
        activeExams: [tExam],
        selectedExam: tExam,
      ),
      act: (cubit) => cubit.deleteExamCountdown(tExam.id),
      expect: () => [
        isA<CramPlannerState>().having((s) => s.status, 'status', CramPlannerStatus.loading),
        isA<CramPlannerState>()
            .having((s) => s.status, 'status', CramPlannerStatus.loaded)
            .having((s) => s.activeExams.isEmpty, 'activeExams.isEmpty', isTrue)
            .having((s) => s.selectedExam, 'selectedExam', isNull),
      ],
    );
  });
}
