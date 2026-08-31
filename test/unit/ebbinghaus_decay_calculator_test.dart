import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/logic/ebbinghaus_decay_calculator.dart';

void main() {
  group('EbbinghausDecayCalculator Math Test Suite', () {
    const calculator = EbbinghausDecayCalculator();

    test('calculateRetention returns 1.0 on day 0 and decays over time', () {
      final r0 = calculator.calculateRetention(stability: 5, daysElapsed: 0);
      final r3 = calculator.calculateRetention(stability: 5, daysElapsed: 3);
      final r10 = calculator.calculateRetention(
        stability: 5,
        daysElapsed: 10,
      );

      expect(r0, equals(1.0));
      expect(r3, lessThan(1.0));
      expect(r10, lessThan(r3));
      expect(r10, greaterThan(0.0));
    });

    test('calculateSevenDayProjection returns 7 points with workloads', () {
      const stabilities = [1.0, 3.0, 5.0, 7.0, 14.0];
      final points = calculator.calculateSevenDayProjection(
        cardStabilities: stabilities,
      );

      expect(points.length, equals(7));
      expect(points.first.day, equals(0));
      expect(points.last.day, equals(6));
      expect(points.first.predictedRetention, equals(1.0));
      expect(points.last.predictedRetention, lessThan(1.0));
      expect(points.first.dueCardsCount, greaterThan(0));
    });
  });
}
