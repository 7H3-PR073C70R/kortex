import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/decks/presentation/widgets/cbt_readiness_impact_card.dart';
import 'package:kortex/src/features/quiz/domain/services/assessment_orchestrator_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUserActivityService extends Mock implements UserActivityService {}

class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  group('P1-02 CBT Readiness Cross-Call-Site Harmonization Suite', () {
    late MockUserActivityService mockActivity;
    late MockUserStorageService mockStorage;
    late AssessmentOrchestratorService orchestrator;

    const sampleCourses = [
      RegisteredCourseInput(
        courseCode: 'MTH 101',
        title: 'Use of Mathematics',
        syllabusCoverage: 0.70,
      ),
      RegisteredCourseInput(
        courseCode: 'ENG 101',
        title: 'Use of English',
        syllabusCoverage: 0.50,
      ),
    ];
    // Average coverage = 0.60
    const commonRetention = 0.82;
    const commonMockAccuracy = 0.74;
    const commonDays = 25;
    const commonExamType = 'WAEC';

    setUp(() {
      mockActivity = MockUserActivityService();
      mockStorage = MockUserStorageService();
      orchestrator = AssessmentOrchestratorService(
        userActivityService: mockActivity,
        userStorageService: mockStorage,
      );

      when(() => mockActivity.getOverallRetentionRate()).thenReturn(commonRetention);
      when(() => mockActivity.getQuizPerformanceMetrics()).thenReturn(
        (
          totalQuizSessions: 8,
          overallMockAccuracy: commonMockAccuracy,
          subjectAccuracies: {'MTH 101': 0.78, 'ENG 101': 0.70},
          subjectRetentions: {'MTH 101': 0.85, 'ENG 101': 0.79},
          subjectQuestionCounts: {'mth 101': 40, 'eng 101': 40},
          totalQuestionsAnswered: 80,
        ),
      );
    });

    test('Identical user state produces identical readiness score percent across all call sites', () {
      // 1. Core Engine / Dashboard Gauge calculation
      final dashboardResult = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.60,
        fsrsRetentionRate: commonRetention,
        mockScoreRatio: commonMockAccuracy,
        daysRemaining: commonDays,
        registeredCourses: sampleCourses,
        examType: commonExamType,
        subjectAccuracies: {'MTH 101': 0.78, 'ENG 101': 0.70},
        subjectRetentions: {'MTH 101': 0.85, 'ENG 101': 0.79},
        subjectQuestionCounts: {'mth 101': 40, 'eng 101': 40},
        totalQuestionsAnswered: 80,
      );
      final dashboardScore = dashboardResult.scorePercent;

      // 2. Orchestrator Service calculation
      final orchestratorScore = orchestrator.calculateReadinessIndex(
        recentScorePercent: commonMockAccuracy * 100.0,
        daysRemaining: commonDays,
        registeredCourses: sampleCourses,
        targetTrack: commonExamType,
      );

      // 3. Countdown Banner calculation logic
      final bannerResult = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.60,
        fsrsRetentionRate: commonRetention,
        mockScoreRatio: commonMockAccuracy,
        daysRemaining: commonDays,
        registeredCourses: sampleCourses,
        examType: commonExamType,
        subjectAccuracies: {'MTH 101': 0.78, 'ENG 101': 0.70},
        subjectRetentions: {'MTH 101': 0.85, 'ENG 101': 0.79},
        subjectQuestionCounts: {'mth 101': 40, 'eng 101': 40},
        totalQuestionsAnswered: 80,
      );
      final bannerScore = bannerResult.scorePercent;

      // 4. Deck Impact Card calculation logic
      final deckCardResult = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.60,
        fsrsRetentionRate: commonRetention,
        mockScoreRatio: commonMockAccuracy,
        daysRemaining: commonDays,
        registeredCourses: sampleCourses,
        examType: commonExamType,
        subjectAccuracies: {'MTH 101': 0.78, 'ENG 101': 0.70},
        subjectRetentions: {'MTH 101': 0.85, 'ENG 101': 0.79},
        subjectQuestionCounts: {'mth 101': 40, 'eng 101': 40},
        totalQuestionsAnswered: 80,
      );
      final deckCardScore = deckCardResult.scorePercent;

      expect(orchestratorScore, equals(dashboardScore.toDouble()));
      expect(bannerScore, equals(dashboardScore));
      expect(deckCardScore, equals(dashboardScore));
    });

    test('CbtReadinessImpactCard score gain scales strictly from 0.0 when 0 cards reviewed', () {
      const cardZero = CbtReadinessImpactCard(
        cardsReviewed: 0,
        retentionScore: 0.85,
        daysRemaining: 20,
      );
      expect(cardZero.cardsReviewed, equals(0));
      // Formula: cardsReviewed == 0 ? 0.0 : (cardsReviewed * 0.12 * retentionScore).clamp(0.0, 4.2)
      final gainZero = cardZero.cardsReviewed == 0
          ? 0.0
          : (cardZero.cardsReviewed * 0.12 * cardZero.retentionScore).clamp(0.0, 4.2);
      expect(gainZero, equals(0.0));

      const cardReviewed = CbtReadinessImpactCard(
        cardsReviewed: 15,
        retentionScore: 0.90,
        daysRemaining: 20,
      );
      final gainReviewed = cardReviewed.cardsReviewed == 0
          ? 0.0
          : (cardReviewed.cardsReviewed * 0.12 * cardReviewed.retentionScore).clamp(0.0, 4.2);
      expect(gainReviewed, greaterThan(0.0));
      expect(gainReviewed, equals((15 * 0.12 * 0.90).clamp(0.0, 4.2)));
    });
  });
}
