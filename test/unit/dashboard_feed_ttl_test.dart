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

class MockCalibrationRepository extends Mock
    implements CalibrationRepository {}

void main() {
  group('DashboardRepositoryImpl 5-Minute In-Memory TTL Cache Suite', () {
    late MockDashboardRemoteDataSource mockRemoteDataSource;
    late MockCalibrationRepository mockCalibrationRepository;
    late DashboardRepositoryImpl repository;
    late DateTime currentTime;

    const tFeedModel = DashboardFeedModel(
      analyticsSummary: AnalyticsSummaryModel(
        currentStreakDays: 5,
        longestStreakDays: 12,
        weeklyMinutesStudied: 200,
        overallRetentionRate: 0.91,
        totalCardsMastered: 110,
        heatMapData: [],
        xpPoints: 850,
        academicRank: 'Neural Scholar',
      ),
      dueStudyDecks: [],
      curatedCourses: [],
      unreadNotificationCount: 2,
      syllabotDailyInsight: 'Keep going!',
    );

    setUp(() {
      mockRemoteDataSource = MockDashboardRemoteDataSource();
      mockCalibrationRepository = MockCalibrationRepository();
      currentTime = DateTime(2026, 9, 6, 12);

      repository = DashboardRepositoryImpl(
        remoteDataSource: mockRemoteDataSource,
        calibrationRepository: mockCalibrationRepository,
        clock: () => currentTime,
      );

      when(
        () => mockCalibrationRepository.getCalibrationProfile(),
      ).thenAnswer(
        (_) async => const Right(
          CalibrationProfile(
            higherEdField: 'Computer Science',
            isCalibrated: true,
          ),
        ),
      );
    });

    test('initial call fetches from remoteDataSource and populates cache', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);

      final result = await repository.getDashboardFeed();

      expect(result.isRight, isTrue);
      result.fold(
        (_) => fail('Expected Right'),
        (feed) {
          expect(feed.syllabotDailyInsight, equals('Keep going!'));
          expect(feed.unreadNotificationCount, equals(2));
        },
      );

      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);
    });

    test('subsequent call within 5 minutes returns cached entity without remote query', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);

      // Initial fetch at 12:00
      final result1 = await repository.getDashboardFeed();
      expect(result1.isRight, isTrue);

      // Advance clock by 4 minutes and 59 seconds (within 5 min TTL)
      currentTime = currentTime.add(const Duration(minutes: 4, seconds: 59));

      // Second fetch should hit in-memory cache
      final result2 = await repository.getDashboardFeed();
      expect(result2.isRight, isTrue);

      // Verify remote data source was called exactly ONCE across both queries
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);
    });

    test('call after 5 minutes TTL expiration triggers fresh remote fetch', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);

      // Initial fetch at 12:00
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);

      // Advance clock past 5 minutes (e.g. 5 minutes 1 second)
      currentTime = currentTime.add(const Duration(minutes: 5, seconds: 1));

      // Next query must refetch from remote
      final result2 = await repository.getDashboardFeed();
      expect(result2.isRight, isTrue);

      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);
    });

    test('forceRefresh: true bypasses active TTL cache and triggers remote fetch', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);

      // Initial fetch at 12:00
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);

      // Advance clock only by 30 seconds
      currentTime = currentTime.add(const Duration(seconds: 30));

      // Force refresh query
      final result2 = await repository.getDashboardFeed(forceRefresh: true);
      expect(result2.isRight, isTrue);

      // Verify remote fetch was called a second time
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);
    });

    test('clearFeedCache manually invalidates cache and triggers remote fetch', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);

      // Initial fetch
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);

      // Clear cache
      repository.clearFeedCache();

      // Query again within 10 seconds
      currentTime = currentTime.add(const Duration(seconds: 10));
      final result2 = await repository.getDashboardFeed();
      expect(result2.isRight, isTrue);

      // Verify remote fetch was called again
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);
    });

    test('course mutations automatically invalidate the feed cache', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);
      when(
        () => mockRemoteDataSource.syncUserCourses(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockRemoteDataSource.autoCurateExamCourses(
          examName: any(named: 'examName'),
          subjects: any(named: 'subjects'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRemoteDataSource.deleteCuratedCourse(any()),
      ).thenAnswer((_) async {});

      // 1. Initial fetch
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);

      // 2. Sync courses invalidates cache
      await repository.syncUserCourses([]);
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);

      // 3. Auto curate invalidates cache
      await repository.autoCurateExamCourses(examName: 'UTME', subjects: ['Math']);
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);

      // 4. Delete course invalidates cache
      await repository.deleteCuratedCourse('c_1');
      await repository.getDashboardFeed();
      verify(() => mockRemoteDataSource.getDashboardFeed()).called(1);
    });

    test('remote failure returns Left and does not populate cache', () async {
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenThrow(Exception('RPC Network failure'));

      final result1 = await repository.getDashboardFeed();
      expect(result1.isLeft, isTrue);

      // Now mock success
      when(
        () => mockRemoteDataSource.getDashboardFeed(),
      ).thenAnswer((_) async => tFeedModel);

      // Second call must attempt remote fetch because cache was never set
      final result2 = await repository.getDashboardFeed();
      expect(result2.isRight, isTrue);

      verify(() => mockRemoteDataSource.getDashboardFeed()).called(2);
    });
  });
}
