import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/quiz/domain/services/assessment_orchestrator_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUserActivityService extends Mock implements UserActivityService {}

class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  group('AssessmentOrchestratorService Readiness Calculation Suite', () {
    late MockUserActivityService mockActivity;
    late MockUserStorageService mockStorage;
    late AssessmentOrchestratorService service;

    setUp(() {
      mockActivity = MockUserActivityService();
      mockStorage = MockUserStorageService();
      service = AssessmentOrchestratorService(
        userActivityService: mockActivity,
        userStorageService: mockStorage,
      );

      when(() => mockActivity.getOverallRetentionRate()).thenReturn(0.80);
      when(() => mockActivity.getQuizPerformanceMetrics()).thenReturn(
        (
          totalQuizSessions: 5,
          overallMockAccuracy: 0.75,
          subjectAccuracies: {'MTH 101': 0.82, 'PHY 102': 0.68},
          subjectRetentions: {'MTH 101': 0.85, 'PHY 102': 0.75},
          subjectQuestionCounts: {'mth 101': 50, 'phy 102': 30},
          totalQuestionsAnswered: 80,
        ),
      );
    });

    test('calculateReadinessIndex uses explicit syllabusCoverage when provided', () {
      final score = service.calculateReadinessIndex(
        recentScorePercent: 75,
        daysRemaining: 30,
        syllabusCoverage: 0.60,
        targetTrack: 'WAEC',
      );

      final expected = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.60,
        fsrsRetentionRate: 0.80,
        mockScoreRatio: 0.75,
        daysRemaining: 30,
        examType: 'WAEC',
        subjectAccuracies: {'MTH 101': 0.82, 'PHY 102': 0.68},
        subjectRetentions: {'MTH 101': 0.85, 'PHY 102': 0.75},
        subjectQuestionCounts: {'mth 101': 50, 'phy 102': 30},
        totalQuestionsAnswered: 80,
      ).scorePercent.toDouble();

      expect(score, equals(expected));
    });

    test('calculateReadinessIndex computes real average coverage from registeredCourses', () {
      final courses = [
        const RegisteredCourseInput(
          courseCode: 'MTH 101',
          title: 'Mathematics',
          syllabusCoverage: 0.80,
        ),
        const RegisteredCourseInput(
          courseCode: 'PHY 102',
          title: 'Physics',
          syllabusCoverage: 0.40,
        ),
      ];

      final score = service.calculateReadinessIndex(
        recentScorePercent: 80,
        daysRemaining: 20,
        registeredCourses: courses,
        targetTrack: 'WAEC',
      );

      // Average coverage of 0.80 and 0.40 is 0.60
      final expected = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.60,
        fsrsRetentionRate: 0.80,
        mockScoreRatio: 0.80,
        daysRemaining: 20,
        registeredCourses: courses,
        examType: 'WAEC',
        subjectAccuracies: {'MTH 101': 0.82, 'PHY 102': 0.68},
        subjectRetentions: {'MTH 101': 0.85, 'PHY 102': 0.75},
        subjectQuestionCounts: {'mth 101': 50, 'phy 102': 30},
        totalQuestionsAnswered: 80,
      ).scorePercent.toDouble();

      expect(score, equals(expected));
    });

    test('calculateReadinessIndex defaults coverage to 0 when unattempted and no courses provided (no synthetic 0.90 retention fabrication)', () {
      final score = service.calculateReadinessIndex(
        recentScorePercent: 70,
        daysRemaining: 15,
        targetTrack: 'WAEC',
      );

      final expected = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0,
        fsrsRetentionRate: 0.80,
        mockScoreRatio: 0.7,
        daysRemaining: 15,
        examType: 'WAEC',
        subjectAccuracies: {'MTH 101': 0.82, 'PHY 102': 0.68},
        subjectRetentions: {'MTH 101': 0.85, 'PHY 102': 0.75},
        subjectQuestionCounts: {'mth 101': 50, 'phy 102': 30},
        totalQuestionsAnswered: 80,
      ).scorePercent.toDouble();

      expect(score, equals(expected));
      // In the old broken code, coverage was fabricated as overallRetention * 0.90 = 0.72.
      // With real 0 coverage, score is strictly calibrated.
      final oldFabricatedScore = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.80 * 0.90, // 0.72
        fsrsRetentionRate: 0.80,
        mockScoreRatio: 0.7,
        daysRemaining: 15,
        examType: 'WAEC',
        subjectAccuracies: {'MTH 101': 0.82, 'PHY 102': 0.68},
        subjectRetentions: {'MTH 101': 0.85, 'PHY 102': 0.75},
      ).scorePercent.toDouble();

      expect(score, isNot(equals(oldFabricatedScore)));
    });
  });
}
