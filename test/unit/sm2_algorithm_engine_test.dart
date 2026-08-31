import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

void main() {
  group('SM-2 Algorithm Engine Mathematical Test Suite', () {
    const engine = Sm2AlgorithmEngine();
    final baseDate = DateTime(2026, 8, 31, 12);

    test('Initial review with quality 5 schedules 1 day and boosts ease', () {
      final result = engine.calculate(
        quality: 5,
        previousInterval: 0,
        previousRepetitions: 0,
        referenceDate: baseDate,
      );

      expect(result.nextInterval, equals(1));
      expect(result.newRepetitions, equals(1));
      expect(result.newEaseFactor, equals(2.6));
      expect(result.nextDueDate, equals(baseDate.add(const Duration(days: 1))));
    });

    test('Second consecutive review with quality 4 schedules 6 days', () {
      final result = engine.calculate(
        quality: 4,
        previousInterval: 1,
        previousRepetitions: 1,
        previousEaseFactor: 2.6,
        referenceDate: baseDate,
      );

      expect(result.nextInterval, equals(6));
      expect(result.newRepetitions, equals(2));
      expect(result.newEaseFactor, equals(2.6));
      expect(result.nextDueDate, equals(baseDate.add(const Duration(days: 6))));
    });

    test('Third consecutive review multiplies interval by ease factor', () {
      final result = engine.calculate(
        quality: 4,
        previousInterval: 6,
        previousRepetitions: 2,
        previousEaseFactor: 2.6,
        referenceDate: baseDate,
      );

      // 6 * 2.6 = 15.6 -> rounded to 16
      expect(result.nextInterval, equals(16));
      expect(result.newRepetitions, equals(3));
      expect(result.newEaseFactor, equals(2.6));
      expect(
        result.nextDueDate,
        equals(baseDate.add(const Duration(days: 16))),
      );
    });

    test('Failed recall (quality 0..2) resets repetition count and interval',
        () {
      for (final failedQuality in [0, 1, 2]) {
        final result = engine.calculate(
          quality: failedQuality,
          previousInterval: 16,
          previousRepetitions: 3,
          previousEaseFactor: 2.6,
          referenceDate: baseDate,
        );

        expect(result.nextInterval, equals(1));
        expect(result.newRepetitions, equals(0));
        expect(result.newEaseFactor, lessThan(2.6));
        expect(
          result.nextDueDate,
          equals(baseDate.add(const Duration(days: 1))),
        );
      }
    });

    test('Ease factor is strictly clamped to a minimum lower bound of 1.3', () {
      var easeFactor = 1.4;

      for (var i = 0; i < 5; i++) {
        final result = engine.calculate(
          quality: 0,
          previousInterval: 1,
          previousRepetitions: 0,
          previousEaseFactor: easeFactor,
          referenceDate: baseDate,
        );
        easeFactor = result.newEaseFactor;
      }

      expect(easeFactor, equals(1.3));
    });

    test('Quality ratings outside 0..5 are safely clamped', () {
      final clampedLow = engine.calculate(
        quality: -2,
        previousInterval: 0,
        previousRepetitions: 0,
        referenceDate: baseDate,
      );
      expect(clampedLow.newRepetitions, equals(0));
      expect(clampedLow.nextInterval, equals(1));

      final clampedHigh = engine.calculate(
        quality: 10,
        previousInterval: 0,
        previousRepetitions: 0,
        referenceDate: baseDate,
      );
      expect(clampedHigh.newRepetitions, equals(1));
      expect(clampedHigh.nextInterval, equals(1));
      expect(clampedHigh.newEaseFactor, equals(2.6));
    });
  });
}
