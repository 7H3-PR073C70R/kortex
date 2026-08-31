import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';

void main() {
  group('SchedulerFactory Dynamic Switching Test Suite', () {
    late SchedulerFactory factory;

    setUp(() {
      factory = SchedulerFactory();
    });

    test('calculates interval via SM-2 when sm2 algorithm is selected', () {
      final result = factory.calculate(
        algorithm: SpacedRepetitionAlgorithm.sm2,
        rating: 4,
        previousInterval: 6,
        previousReps: 2,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.sm2));
      expect(result.sm2Result, isNotNull);
      expect(result.nextIntervalDays, greaterThanOrEqualTo(6));
    });

    test('calculates interval via FSRS-4.5 when fsrs is selected', () {
      final result = factory.calculate(
        algorithm: SpacedRepetitionAlgorithm.fsrs,
        rating: 3,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(result.fsrsState, isNotNull);
      expect(result.fsrsState?.stability, equals(2.4));
      expect(result.nextIntervalDays, greaterThanOrEqualTo(2));
    });
  });
}
