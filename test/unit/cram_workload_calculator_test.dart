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

    test('FSRS-6 retrievability calculation matches power-law forgetting curve', () {
      // At elapsedDays = 0, R = 1.0
      expect(calculator.calculateRetrievability(stability: 10, elapsedDays: 0), equals(1.0));

      // At elapsedDays = stability, R should be 0.90
      final rAtS = calculator.calculateRetrievability(stability: 10, elapsedDays: 10);
      expect((rAtS * 100).round(), equals(90));

      // As elapsed days increase, retrievability decays monotonically
      final rAt20 = calculator.calculateRetrievability(stability: 10, elapsedDays: 20);
      expect(rAt20 < rAtS, isTrue);

      // Stability <= 0 returns 0.0
      expect(calculator.calculateRetrievability(stability: 0, elapsedDays: 5), equals(0.0));
    });

    test('calculateExamReadinessScore accurately combines coverage, stability, and difficulty', () {
      // 100% mastered, high stability, 0 lapses => high score
      final highScore = calculator.calculateExamReadinessScore(
        totalCards: 100,
        masteredCards: 100,
        averageStability: 30,
        averageDifficulty: 3,
        daysRemaining: 5,
      );
      expect(highScore > 90.0, isTrue);

      // 0 cards mastered => low score
      final lowScore = calculator.calculateExamReadinessScore(
        totalCards: 100,
        masteredCards: 0,
        averageStability: 0,
        averageDifficulty: 8,
        daysRemaining: 5,
        totalLapses: 20,
      );
      expect(lowScore < 10.0, isTrue);

      // Total cards = 0 returns 0.0
      expect(
        calculator.calculateExamReadinessScore(
          totalCards: 0,
          masteredCards: 0,
          averageStability: 10,
          daysRemaining: 5,
        ),
        equals(0.0),
      );
    });

    test('predictRetentionTrajectory returns monotonic decay projection over days remaining', () {
      final trajectory = calculator.predictRetentionTrajectory(
        initialStability: 15,
        daysRemaining: 10,
      );
      expect(trajectory.length, equals(11)); // 0 through 10
      expect(trajectory.first, equals(100.0)); // Day 0 is 100%

      for (var i = 1; i < trajectory.length; i++) {
        expect(trajectory[i] <= trajectory[i - 1], isTrue);
      }
    });
  });
}
