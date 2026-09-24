import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/planner/domain/entities/assessment_type.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
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

    test('AssessmentType-specific urgency thresholds prevent artificial panic', () {
      // Quiz: short horizon (< 24h critical, 1-3d warning, >3d normal)
      expect(calculator.getUrgencyLevel(4, type: AssessmentType.quiz), equals(ExamUrgencyLevel.normal));
      expect(calculator.getUrgencyLevel(2, type: AssessmentType.quiz), equals(ExamUrgencyLevel.warning));
      expect(calculator.getUrgencyLevel(0, type: AssessmentType.quiz), equals(ExamUrgencyLevel.critical));

      // Class Test: continuous assessment (< 3d critical, 3-7d warning, >7d normal)
      expect(calculator.getUrgencyLevel(8, type: AssessmentType.classTest), equals(ExamUrgencyLevel.normal));
      expect(calculator.getUrgencyLevel(5, type: AssessmentType.classTest), equals(ExamUrgencyLevel.warning));
      expect(calculator.getUrgencyLevel(2, type: AssessmentType.classTest), equals(ExamUrgencyLevel.critical));

      // Midterm: (< 5d critical, 5-14d warning, >14d normal)
      expect(calculator.getUrgencyLevel(16, type: AssessmentType.midterm), equals(ExamUrgencyLevel.normal));
      expect(calculator.getUrgencyLevel(10, type: AssessmentType.midterm), equals(ExamUrgencyLevel.warning));
      expect(calculator.getUrgencyLevel(4, type: AssessmentType.midterm), equals(ExamUrgencyLevel.critical));
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

    group('Study Priority Index (SPI) Suite', () {
      test('Completed or past exams return 0.0 priority score', () {
        final completedExam = ExamEventEntity(
          id: 'exam-c',
          userId: 'u1',
          examName: 'Completed Quiz',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(days: 3)),
          isCompleted: true,
        );
        expect(calculator.calculatePriorityScore(exam: completedExam), equals(0.0));

        final pastExam = ExamEventEntity(
          id: 'exam-p',
          userId: 'u1',
          examName: 'Past Exam',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().subtract(const Duration(days: 2)),
        );
        expect(calculator.calculatePriorityScore(exam: pastExam), equals(0.0));
      });

      test('Critical imminent exam with high weight scores significantly higher than distant low weight exam', () {
        final imminentFinal = ExamEventEntity(
          id: 'imminent-final',
          userId: 'u1',
          examName: 'Final Exam Tomorrow',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(hours: 18)),
          weightPercent: 0.50,
          totalCardsCount: 100,
          dailyTarget: 40,
        );

        final distantQuiz = ExamEventEntity(
          id: 'distant-quiz',
          userId: 'u1',
          examName: 'Quiz in 3 Weeks',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(days: 21)),
          assessmentType: AssessmentType.quiz,
          weightPercent: 0.10,
          totalCardsCount: 20,
          dailyTarget: 2,
        );

        final scoreImminent = calculator.calculatePriorityScore(exam: imminentFinal);
        final scoreDistant = calculator.calculatePriorityScore(exam: distantQuiz);

        expect(scoreImminent > scoreDistant, isTrue);
        expect(scoreImminent >= 70.0, isTrue);
        expect(calculator.calculatePriorityLevel(exam: imminentFinal), equals(StudyPriorityLevel.critical));
      });

      test('Priority level categorization maps accurately to discrete levels', () {
        final highPriority = ExamEventEntity(
          id: 'high-p',
          userId: 'u1',
          examName: 'Midterm Soon',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(days: 3)),
          assessmentType: AssessmentType.midterm,
          weightPercent: 0.35,
          totalCardsCount: 80,
          dailyTarget: 25,
        );

        final level = calculator.calculatePriorityLevel(exam: highPriority);
        expect(level == StudyPriorityLevel.critical || level == StudyPriorityLevel.high, isTrue);
      });
    });

    group('Consolidated Daily Workload & Time Estimation Suite', () {
      test('calculateTotalDailyWorkload aggregates active upcoming exams and ignores completed/past ones', () {
        final activeExam1 = ExamEventEntity(
          id: 'e1',
          userId: 'u1',
          examName: 'Active Exam 1',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(days: 5)),
          totalCardsCount: 50,
        );
        final activeExam2 = ExamEventEntity(
          id: 'e2',
          userId: 'u1',
          examName: 'Active Exam 2',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(days: 10)),
          totalCardsCount: 100,
        );
        final completedExam = ExamEventEntity(
          id: 'e3',
          userId: 'u1',
          examName: 'Completed Exam',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().add(const Duration(days: 2)),
          totalCardsCount: 80,
          isCompleted: true,
        );
        final pastExam = ExamEventEntity(
          id: 'e4',
          userId: 'u1',
          examName: 'Past Exam',
          subjectTrack: 'MTH 101',
          targetDate: DateTime.now().subtract(const Duration(days: 1)),
          totalCardsCount: 80,
        );

        final totalWorkload = calculator.calculateTotalDailyWorkload([
          activeExam1,
          activeExam2,
          completedExam,
          pastExam,
        ]);

        // activeExam1: 50 / 5 = 10
        // activeExam2: 100 / 10 = 10
        // total = 20
        expect(totalWorkload, equals(20));
      });

      test('calculateEstimatedDailyMinutes scales realistically with minimum floor', () {
        expect(calculator.calculateEstimatedDailyMinutes(0), equals(0));
        // 10 cards * 20s = 200s ~ 3.3 mins -> clamped to min floor of 5 mins
        expect(calculator.calculateEstimatedDailyMinutes(10), equals(5));
        // 60 cards * 20s = 1200s = 20 mins
        expect(calculator.calculateEstimatedDailyMinutes(60), equals(20));
        // 120 cards * 20s = 2400s = 40 mins
        expect(calculator.calculateEstimatedDailyMinutes(120), equals(40));
      });
    });
  });
}
