import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/planner/domain/logic/cram_workload_calculator.dart';

void main() {
  group('CramWorkloadCalculator Math & Urgency Suite', () {
    const calculator = CramWorkloadCalculator();

    test(
      'Formula validation: Remaining Cards + (Lapses * 1.5) / Days Remaining',
      () {
        // 100 cards remaining, 0 lapses, 10 days remaining => ceil(100 / 10) = 10
        final paceNormal = calculator.calculateDailyTarget(
          remainingCards: 100,
          lapses: 0,
          daysRemaining: 10,
        );
        expect(paceNormal, equals(10));

        // 100 cards remaining, 4 lapses, 10 days remaining => ceil((100 + 6) / 10) = ceil(10.6) = 11
        final paceWithLapses = calculator.calculateDailyTarget(
          remainingCards: 100,
          lapses: 4,
          daysRemaining: 10,
        );
        expect(paceWithLapses, equals(11));

        // 0 remaining cards returns 0
        final zeroCards = calculator.calculateDailyTarget(
          remainingCards: 0,
          lapses: 0,
          daysRemaining: 5,
        );
        expect(zeroCards, equals(0));

        // 1 day remaining handles full cram workload
        final oneDayPace = calculator.calculateDailyTarget(
          remainingCards: 50,
          lapses: 2,
          daysRemaining: 1,
        );
        expect(oneDayPace, equals(53));
      },
    );

    test('Urgency levels categorization based on days threshold', () {
      expect(calculator.getUrgencyLevel(30), equals(ExamUrgencyLevel.normal));
      expect(calculator.getUrgencyLevel(15), equals(ExamUrgencyLevel.normal));
      expect(calculator.getUrgencyLevel(14), equals(ExamUrgencyLevel.warning));
      expect(calculator.getUrgencyLevel(7), equals(ExamUrgencyLevel.warning));
      expect(calculator.getUrgencyLevel(6), equals(ExamUrgencyLevel.critical));
      expect(calculator.getUrgencyLevel(0), equals(ExamUrgencyLevel.critical));
    });
  });
}
