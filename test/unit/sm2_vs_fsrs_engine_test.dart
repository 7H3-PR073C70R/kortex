// ignore_for_file: deprecated_member_use_from_same_package, tests comparing legacy algorithm
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

void main() {
  group('SM-2 vs FSRS-6 Algorithm Comparative Test Suite', () {
    const sm2Engine = Sm2AlgorithmEngine();
    final fsrsEngine = FsrsAlgorithmEngine();
    late SchedulerFactory factory;

    setUp(() {
      factory = SchedulerFactory(
        sm2Engine: sm2Engine,
        fsrsEngine: fsrsEngine,
      );
    });

    test(
      'Initial review comparison: SM-2 default vs FSRS-6 rating matrix',
      () {
        // SM-2 Good (Quality 4)
        final sm2Good = sm2Engine.calculate(
          quality: 4,
          previousInterval: 1,
          previousRepetitions: 0,
        );
        expect(sm2Good.nextInterval, equals(1));
        expect(sm2Good.newRepetitions, equals(1));

        // FSRS Good (Rating 3)
        final fsrsGood = fsrsEngine.review(
          currentState: FsrsCardState.initial(),
          rating: FsrsRating.good,
        );
        expect(fsrsGood.reps, equals(1));
        expect(fsrsGood.stability, equals(3.173));
        expect(fsrsGood.scheduledDays, greaterThanOrEqualTo(2));

        // FSRS Easy (Rating 4) gives higher initial stability (15.691)
        final fsrsEasy = fsrsEngine.review(
          currentState: FsrsCardState.initial(),
          rating: FsrsRating.easy,
        );
        expect(fsrsEasy.stability, equals(15.691));
        expect(fsrsEasy.scheduledDays, greaterThanOrEqualTo(6));
      },
    );

    test(
      'Lapse handling: SM-2 resets repetitions, FSRS increments lapse count',
      () {
        // SM-2 Again (Quality 1)
        final sm2Lapse = sm2Engine.calculate(
          quality: 1,
          previousInterval: 15,
          previousRepetitions: 4,
          previousEaseFactor: 2.3,
        );
        expect(sm2Lapse.nextInterval, equals(1));
        expect(sm2Lapse.newRepetitions, equals(0));

        // FSRS Lapse
        final matureState = FsrsCardState(
          stability: 14,
          difficulty: 4.5,
          retrievability: 0.9,
          elapsedDays: 14,
          scheduledDays: 14,
          reps: 4,
          lapses: 0,
          nextDueDate: DateTime.now().add(const Duration(days: 14)),
        );

        final fsrsLapse = fsrsEngine.review(
          currentState: matureState,
          rating: FsrsRating.again,
        );
        expect(fsrsLapse.lapses, equals(1));
        expect(fsrsLapse.scheduledDays, equals(2));
        expect(fsrsLapse.stability, lessThanOrEqualTo(matureState.stability));
      },
    );

    test(
      'SchedulerFactory outputs unified result powered by FSRS-6',
      () {
        final sm2Result = factory.calculate(
          algorithm: SpacedRepetitionAlgorithm.sm2,
          rating: 5,
          previousInterval: 6,
          previousReps: 2,
        );

        final fsrsResult = factory.calculate(
          rating: 4,
        );

        expect(sm2Result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
        expect(sm2Result.fsrsState, isNotNull);
        expect(fsrsResult.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
        expect(fsrsResult.fsrsState, isNotNull);
      },
    );
  });
}
