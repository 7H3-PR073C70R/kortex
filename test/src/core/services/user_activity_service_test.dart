import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MockLocalStorageService mockStorage;
  late UserActivityServiceImpl activityService;
  late Map<String, String> inMemoryPrefs;

  setUp(() {
    mockStorage = MockLocalStorageService();
    inMemoryPrefs = {};

    when(() => mockStorage.getPreference(key: any(named: 'key')))
        .thenAnswer((invocation) {
      final key = invocation.namedArguments[#key] as String;
      return inMemoryPrefs[key];
    });

    when(() => mockStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        )).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final data = invocation.namedArguments[#data] as String;
      inMemoryPrefs[key] = data;
    });

    activityService = UserActivityServiceImpl(mockStorage);
  });

  group('UserActivityService Test Suite', () {
    test('initial state returns zeros and defaults', () {
      expect(activityService.getCurrentStreak(), equals(0));
      expect(activityService.getLongestStreak(), equals(0));
      expect(activityService.getTotalCardsMastered(), equals(0));
      expect(activityService.getWeeklyMinutesStudied(), equals(0));
      expect(activityService.getOverallRetentionRate(), equals(0.0));
      expect(activityService.getXpPoints(), equals(0));
      expect(activityService.getAcademicRank(), equals('Neural Scholar I'));

      final heatMap = activityService.getHeatMapData();
      expect(heatMap.length, equals(28));
      expect(heatMap.every((h) => h.intensityLevel == 0), isTrue);
    });

    test('recordStudySession increments streak and calculates KPIs', () async {
      await activityService.recordStudySession(
        cardsReviewed: 20,
        durationSeconds: 300, // 5 minutes
        retentionScore: 0.90,
        masteredCards: 18,
      );

      expect(activityService.getCurrentStreak(), equals(1));
      expect(activityService.getLongestStreak(), equals(1));
      expect(activityService.getTotalCardsMastered(), equals(18));
      expect(activityService.getWeeklyMinutesStudied(), equals(5));
      expect(activityService.getOverallRetentionRate(), equals(0.90));
      // XP: (20 * 10) + (5 * 5) + 50 + (1 * 30) = 200 + 25 + 50 + 30 = 305
      expect(activityService.getXpPoints(), equals(305));
      expect(activityService.getAcademicRank(), equals('Neural Scholar II'));

      final heatMap = activityService.getHeatMapData();
      final today = heatMap.last;
      expect(today.cardsReviewed, equals(20));
      expect(today.minutesStudied, equals(5));
      expect(today.intensityLevel, greaterThan(0));
    });

    test('multiple sessions aggregate retention, cards, and study volume',
        () async {
      await activityService.recordStudySession(
        cardsReviewed: 10,
        durationSeconds: 120, // 2 mins
        retentionScore: 0.80,
        masteredCards: 8,
      );

      await activityService.recordStudySession(
        cardsReviewed: 15,
        durationSeconds: 180, // 3 mins
        retentionScore: 1,
        masteredCards: 15,
      );

      expect(activityService.getTotalCardsMastered(), equals(23));
      expect(activityService.getWeeklyMinutesStudied(), equals(5));
      expect(activityService.getOverallRetentionRate(), closeTo(0.90, 0.01));
      // Same day multiple sessions keep streak at 1
      expect(activityService.getCurrentStreak(), equals(1));
    });

    test('getAnalyticsSummary returns complete structured model', () async {
      await activityService.recordStudySession(
        cardsReviewed: 25,
        durationSeconds: 600,
        retentionScore: 0.88,
        masteredCards: 22,
      );

      final summary = activityService.getAnalyticsSummary();
      expect(summary.currentStreakDays, equals(1));
      expect(summary.longestStreakDays, equals(1));
      expect(summary.totalCardsMastered, equals(22));
      expect(summary.weeklyMinutesStudied, equals(10));
      expect(summary.overallRetentionRate, closeTo(0.88, 0.01));
      expect(summary.heatMapData.length, equals(28));
      expect(summary.xpPoints, greaterThan(0));
    });
  });
}
