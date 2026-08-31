import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/logic/sm2_algorithm_engine.dart';

void main() {
  group('Sm2AlgorithmEngine', () {
    const engine = Sm2AlgorithmEngine();
    final fixedNow = DateTime(2026, 8, 31, 12);

    test('resets repetitions to 0 and interval to 1 on failure (q < 3)', () {
      final result = engine.calculate(
        quality: 0, // Again
        previousInterval: 12,
        previousRepetitions: 4,
        referenceDate: fixedNow,
      );

      expect(result.newRepetitions, 0);
      expect(result.nextInterval, 1);
      expect(result.nextDueDate, fixedNow.add(const Duration(days: 1)));
    });

    test('sets interval to 1 on first successful review (rep == 0, q >= 3)',
        () {
      final result = engine.calculate(
        quality: 4, // Good
        previousInterval: 0,
        previousRepetitions: 0,
        referenceDate: fixedNow,
      );

      expect(result.newRepetitions, 1);
      expect(result.nextInterval, 1);
    });

    test('sets interval to 6 on second successful review (rep == 1, q >= 3)',
        () {
      final result = engine.calculate(
        quality: 4, // Good
        previousInterval: 1,
        previousRepetitions: 1,
        referenceDate: fixedNow,
      );

      expect(result.newRepetitions, 2);
      expect(result.nextInterval, 6);
    });

    test('scales interval by easeFactor on subsequent reviews (rep > 1)', () {
      final result = engine.calculate(
        quality: 4, // Good
        previousInterval: 6,
        previousRepetitions: 2,
        referenceDate: fixedNow,
      );

      expect(result.newRepetitions, 3);
      expect(result.nextInterval, (6 * 2.5).round()); // 15
    });

    test('clamps minimum ease factor to 1.3', () {
      final result = engine.calculate(
        quality: 0,
        previousInterval: 1,
        previousRepetitions: 0,
        previousEaseFactor: 1.35,
        referenceDate: fixedNow,
      );

      expect(result.newEaseFactor, 1.3);
    });

    test('correctly increases ease factor for quality 5 (Easy)', () {
      final result = engine.calculate(
        quality: 5,
        previousInterval: 6,
        previousRepetitions: 2,
        referenceDate: fixedNow,
      );

      // EF' = 2.5 + (0.1 - (0) * ...) = 2.6
      expect(result.newEaseFactor, 2.6);
    });
  });
}
