import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_trend_calculator.dart';

void main() {
  group('CbtReadinessTrendCalculator Pure Domain Unit Tests', () {
    const calculator = CbtReadinessTrendCalculator();
    final fixedNow = DateTime(2026, 10, 16, 12);

    test('Zero activity and uncalibrated readiness returns flat 0% baseline', () {
      final points = calculator.calculateWeeklyTrend(
        sessions: const [],
        currentReadinessScore: 0,
        now: fixedNow,
      );

      expect(points.length, equals(6));
      for (final pt in points) {
        expect(pt.readinessScore, equals(0.0));
        expect(pt.testsCompleted, equals(0));
      }
      expect(points.last.weekLabel, equals('Current'));
    });

    test('Current week strictly aligns with currentReadinessScore', () {
      final points = calculator.calculateWeeklyTrend(
        sessions: const [],
        currentReadinessScore: 68.5,
        now: fixedNow,
      );

      expect(points.last.readinessScore, equals(68.5));
    });

    test('Day-One Diagnostic in earlier week establishes calibrated baseline', () {
      // Day 1 diagnostic taken 3 weeks ago (21 days ago) scoring 70%
      final diagnosticDate = fixedNow.subtract(const Duration(days: 21));
      final sessions = [
        {
          'timestamp': diagnosticDate.toIso8601String(),
          'retentionScore': 0.70,
          'category': 'quiz',
          'cardsReviewed': 15,
        },
      ];

      final points = calculator.calculateWeeklyTrend(
        sessions: sessions,
        currentReadinessScore: 72,
        now: fixedNow,
      );

      expect(points.length, equals(6));
      // Weeks prior to the diagnostic should be 0.0
      expect(points[0].readinessScore, equals(0.0));
      expect(points[1].readinessScore, equals(0.0));

      // The week containing the diagnostic should reflect ~70%
      // Week index for 21 days ago: (6 - 1) - (21 ~/ 7) = 5 - 3 = 2
      expect(points[2].readinessScore, equals(70.0));
      expect(points[2].testsCompleted, equals(1));

      // Subsequent inactive weeks carry forward calibrated score with natural retention decay
      expect(points[3].readinessScore, closeTo(68.6, 0.5));
      expect(points[4].readinessScore, closeTo(67.2, 0.5));

      // Current week reflects authoritative current score
      expect(points[5].readinessScore, equals(72.0));
    });

    test('Accurately counts tests across multiple weekly buckets', () {
      final sessions = [
        // 2 tests this week
        {
          'timestamp': fixedNow.subtract(const Duration(days: 2)).toIso8601String(),
          'retentionScore': 0.80,
          'category': 'quiz',
          'cardsReviewed': 20,
        },
        {
          'timestamp': fixedNow.subtract(const Duration(days: 4)).toIso8601String(),
          'retentionScore': 0.85,
          'category': 'cbt_mock',
          'cardsReviewed': 40,
        },
        // 1 test 2 weeks ago
        {
          'timestamp': fixedNow.subtract(const Duration(days: 14)).toIso8601String(),
          'retentionScore': 0.75,
          'category': 'exam',
          'cardsReviewed': 50,
        },
        // Non-assessment activity ignored
        {
          'timestamp': fixedNow.subtract(const Duration(days: 1)).toIso8601String(),
          'retentionScore': 0.90,
          'category': 'flashcard_review',
          'cardsReviewed': 10,
        },
      ];

      final points = calculator.calculateWeeklyTrend(
        sessions: sessions,
        currentReadinessScore: 82,
        weekCount: 5,
        now: fixedNow,
      );

      expect(points.length, equals(5));
      // Current week has 2 assessment tests
      expect(points.last.testsCompleted, equals(2));
      expect(points.last.readinessScore, equals(82.0));
    });
  });
}
