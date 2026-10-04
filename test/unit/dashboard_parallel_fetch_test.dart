import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockDashboardRemoteDataSource extends Mock
    implements DashboardRemoteDataSource {}

class MockCalibrationRepository extends Mock implements CalibrationRepository {}

const _tFeedModel = DashboardFeedModel(
  analyticsSummary: AnalyticsSummaryModel(
    currentStreakDays: 3,
    longestStreakDays: 7,
    weeklyMinutesStudied: 90,
    overallRetentionRate: 0.88,
    totalCardsMastered: 150,
    heatMapData: [],
    xpPoints: 300,
    academicRank: 'Neural Scholar I',
  ),
  dueStudyDecks: [],
  curatedCourses: [],
);

void main() {
  late MockDashboardRemoteDataSource mockSource;
  late MockCalibrationRepository mockCalibration;
  late DashboardRepositoryImpl repository;
  late DateTime currentTime;

  setUp(() {
    mockSource = MockDashboardRemoteDataSource();
    mockCalibration = MockCalibrationRepository();
    currentTime = DateTime(2026, 9, 29, 2);

    repository = DashboardRepositoryImpl(
      remoteDataSource: mockSource,
      calibrationRepository: mockCalibration,
      clock: () => currentTime,
    );

    when(() => mockCalibration.getCalibrationProfile()).thenAnswer(
      (_) async => const Right(CalibrationProfile(isCalibrated: true)),
    );
  });

  group('DashboardRepositoryImpl — parallel fetch performance', () {
    test('getDashboardFeed completes within 100ms when source is instant', () async {
      when(() => mockSource.getDashboardFeed())
          .thenAnswer((_) async => _tFeedModel);

      final stopwatch = Stopwatch()..start();
      final result = await repository.getDashboardFeed();
      stopwatch.stop();

      expect(result.isRight, isTrue);
      // With Future.wait parallelisation, two async paths run concurrently so
      // the total time should be roughly max(t1, t2), not t1 + t2.
      // For instant mocks the overhead should be well under 100ms.
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });

    test('overallRetentionRate is clamped to 1.0 when server sends > 1.0', () async {
      // Security: adversarial server returns retention > 1 (e.g. 1.5).
      const maliciousFeed = DashboardFeedModel(
        analyticsSummary: AnalyticsSummaryModel(
          currentStreakDays: 0,
          longestStreakDays: 0,
          weeklyMinutesStudied: 0,
          overallRetentionRate: 1.5, // invalid — over 100%
          totalCardsMastered: 0,
          heatMapData: [],
          xpPoints: 0,
          academicRank: 'Hacker',
        ),
        dueStudyDecks: [],
        curatedCourses: [],
      );
      when(() => mockSource.getDashboardFeed())
          .thenAnswer((_) async => maliciousFeed);

      final result = await repository.getDashboardFeed();

      result.fold(
        (_) => fail('Expected Right'),
        (feed) {
          expect(
            feed.analyticsSummary.overallRetentionRate,
            lessThanOrEqualTo(1.0),
          );
        },
      );
    });

    test('overallRetentionRate is clamped to 0.0 when server sends < 0', () async {
      const maliciousFeed = DashboardFeedModel(
        analyticsSummary: AnalyticsSummaryModel(
          currentStreakDays: 0,
          longestStreakDays: 0,
          weeklyMinutesStudied: 0,
          overallRetentionRate: -0.5, // invalid — negative
          totalCardsMastered: 0,
          heatMapData: [],
          xpPoints: 0,
          academicRank: 'Hacker',
        ),
        dueStudyDecks: [],
        curatedCourses: [],
      );
      when(() => mockSource.getDashboardFeed())
          .thenAnswer((_) async => maliciousFeed);

      final result = await repository.getDashboardFeed();

      result.fold(
        (_) => fail('Expected Right'),
        (feed) {
          expect(
            feed.analyticsSummary.overallRetentionRate,
            greaterThanOrEqualTo(0.0),
          );
        },
      );
    });

    test('getDashboardFeed returns Right with valid data on success', () async {
      when(() => mockSource.getDashboardFeed())
          .thenAnswer((_) async => _tFeedModel);

      final result = await repository.getDashboardFeed();
      expect(result.isRight, isTrue);
    });

    test('getDashboardFeed uses cache on second call within TTL', () async {
      when(() => mockSource.getDashboardFeed())
          .thenAnswer((_) async => _tFeedModel);

      await repository.getDashboardFeed();
      await repository.getDashboardFeed();

      // Source should only be called once — second call hits cache.
      verify(() => mockSource.getDashboardFeed()).called(1);
    });

    test('getDashboardFeed refetches after TTL expires', () async {
      when(() => mockSource.getDashboardFeed())
          .thenAnswer((_) async => _tFeedModel);

      await repository.getDashboardFeed();

      // Advance clock past 5-minute TTL.
      currentTime = currentTime.add(const Duration(minutes: 5, seconds: 1));

      await repository.getDashboardFeed();

      verify(() => mockSource.getDashboardFeed()).called(2);
    });
  });
}
