// ignore_for_file: deprecated_member_use_from_same_package, tests for legacy scheduler fallback
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/scheduler_factory.dart';

void main() {
  group('SchedulerFactory FSRS-6 Engine Test Suite', () {
    late SchedulerFactory factory;

    setUp(() {
      factory = SchedulerFactory();
    });

    test('calculates interval via FSRS-6 even when legacy sm2 requested', () {
      final result = factory.calculate(
        algorithm: SpacedRepetitionAlgorithm.sm2,
        rating: 4,
        previousInterval: 6,
        previousReps: 2,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(result.fsrsState, isNotNull);
      expect(result.nextIntervalDays, greaterThanOrEqualTo(1));
    });

    test('calculates interval via FSRS-6 with 21 parameter model', () {
      final result = factory.calculate(
        rating: 3,
      );

      expect(result.algorithm, equals(SpacedRepetitionAlgorithm.fsrs));
      expect(result.fsrsState, isNotNull);
      expect(result.fsrsState?.stability, equals(3.173));
      expect(result.nextIntervalDays, greaterThanOrEqualTo(2));
    });
  });
}
