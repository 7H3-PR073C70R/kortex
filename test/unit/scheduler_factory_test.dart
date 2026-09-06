import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';

void main() {
  group('SchedulerFactory FSRS-6 Engine Test Suite', () {
    late SchedulerFactory factory;

    setUp(() {
      factory = SchedulerFactory();
    });

    test('calculates interval via FSRS-6 with 21 parameter model for rating 4 (Easy)', () {
      final result = factory.calculate(
        rating: 4,
        previousInterval: 6,
        previousReps: 2,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(result.fsrsState, isNotNull);
      expect(result.nextIntervalDays, greaterThanOrEqualTo(1));
    });

    test('calculates interval via FSRS-6 with 21 parameter model for rating 3 (Good)', () {
      final result = factory.calculate(
        rating: 3,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(result.fsrsState, isNotNull);
      expect(result.fsrsState?.stability, equals(3.173));
      expect(result.nextIntervalDays, greaterThanOrEqualTo(2));
    });

    test('calculates interval via FSRS-6 for rating 1 (Again)', () {
      final result = factory.calculate(
        rating: 1,
        previousInterval: 10,
        previousReps: 3,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(result.fsrsState, isNotNull);
      expect(result.nextIntervalDays, greaterThanOrEqualTo(1));
    });
  });
}
