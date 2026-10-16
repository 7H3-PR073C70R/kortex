import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/features/dashboard/data/client/dashboard_api_client.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source_impl.dart';
import 'package:kortex/src/features/dashboard/data/models/analytics_summary_model.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/domain/logic/cbt_readiness_calculator.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_local_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';
import 'package:kortex/src/features/onboarding_calibration/data/repositories/calibration_repository_impl.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/quiz/domain/services/cbt_readiness_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockCalibrationLocalDataSource extends Mock
    implements CalibrationLocalDataSource {}

class MockCalibrationRemoteDataSource extends Mock
    implements CalibrationRemoteDataSource {}

class MockDio extends Mock implements Dio {}

class MockDashboardApiClient extends Mock implements DashboardApiClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const CalibrationProfileModel(
        isCalibrated: true,
      ),
    );
  });

  group('Reinstall Data Sync & Persistence Integrity', () {
    test('UserActivityService restores streak, freezes, and XP from remote',
        () async {
      final inMemory = <String, String>{};
      final storage = MockLocalStorageService();

      when(() => storage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemory[inv.namedArguments[#key] as String]);
      when(
        () => storage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        inMemory[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });

      final service = UserActivityServiceImpl(storage);

      // Verify starting state on clean install is 0
      expect(service.getCurrentStreak(), 0);
      expect(service.getXpPoints(), 0);

      // Hydrate from remote profile (simulating login/reinstall)
      await service.hydrateFromRemote(
        streakDays: 14,
        longestStreakDays: 20,
        xpPoints: 1500,
        streakFreezes: 3,
        heatMapData: const [
          HeatMapDayModel(
            dateIso: '2026-10-01T00:00:00.000Z',
            intensityLevel: 3,
            cardsReviewed: 25,
            minutesStudied: 20,
          ),
        ],
      );

      expect(service.getCurrentStreak(), 14);
      expect(service.getLongestStreak(), 20);
      expect(service.getStreakFreezes(), 3);
      expect(service.getXpPoints(), greaterThanOrEqualTo(1500));
    });

    test('CalibrationRepository fetches from remote when local is empty',
        () async {
      final localDS = MockCalibrationLocalDataSource();
      final remoteDS = MockCalibrationRemoteDataSource();

      const remoteModel = CalibrationProfileModel(
        higherEdLevel: 'bsc',
        higherEdField: 'Computer Science',
        isCalibrated: true,
      );

      when(localDS.getCalibrationProfile)
          .thenAnswer((_) async => null);
      when(remoteDS.fetchCalibrationProfile)
          .thenAnswer((_) async => remoteModel);
      when(() => localDS.saveCalibrationProfile(any()))
          .thenAnswer((_) async {});

      final repo = CalibrationRepositoryImpl(
        localDataSource: localDS,
        remoteDataSource: remoteDS,
      );

      final result = await repo.getCalibrationProfile();

      expect(result.isRight, isTrue);
      final profile = result.fold((_) => null, (p) => p);
      expect(profile, isNotNull);
      expect(profile!.isCalibrated, isTrue);
      expect(profile.higherEdField, 'Computer Science');

      // Verify it was cached locally for offline continuity
      verify(() => localDS.saveCalibrationProfile(remoteModel)).called(1);
    });

    test('CalibrationRepository pushes to remote and local on save', () async {
      final localDS = MockCalibrationLocalDataSource();
      final remoteDS = MockCalibrationRemoteDataSource();

      when(() => localDS.saveCalibrationProfile(any()))
          .thenAnswer((_) async {});
      when(() => remoteDS.syncCalibrationProfile(any()))
          .thenAnswer((_) async {});

      final repo = CalibrationRepositoryImpl(
        localDataSource: localDS,
        remoteDataSource: remoteDS,
      );

      const entity = CalibrationProfile(
        higherEdField: 'Medicine',
        isCalibrated: true,
      );

      final result = await repo.saveCalibrationProfile(entity);

      expect(result.isRight, isTrue);
      verify(() => localDS.saveCalibrationProfile(any())).called(1);
      verify(() => remoteDS.syncCalibrationProfile(any())).called(1);
    });

    test(
        'UserActivityService restores quiz attempts, subject accuracies, question count, and CBT readiness on clean install from remoteQuizzes',
        () async {
      final inMemory = <String, String>{};
      final storage = MockLocalStorageService();

      when(() => storage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemory[inv.namedArguments[#key] as String]);
      when(
        () => storage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        inMemory[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });

      final service = UserActivityServiceImpl(storage);

      // Verify starting state on clean install has 0 quiz sessions
      final initialMetrics = service.getQuizPerformanceMetrics();
      expect(initialMetrics.totalQuizSessions, 0);
      expect(initialMetrics.totalQuestionsAnswered, 0);

      final remoteQuizzes = [
        {
          'id': 'quiz-uuid-math',
          'title': 'Mathematics Mock 2024',
          'subject': 'Mathematics',
          'total_questions': 40,
          'correct_answers': 32,
          'score_percent': 80,
          'duration_seconds': 1800,
          'completed_at': '2026-10-14T10:00:00Z',
        },
        {
          'id': 'quiz-uuid-phy',
          'title': 'Physics Mechanics Quiz',
          'subject': 'Physics',
          'total_questions': 40,
          'correct_answers': 28,
          'score_percent': 70,
          'duration_seconds': 1800,
          'completed_at': '2026-10-15T12:00:00Z',
        },
        {
          'id': 'quiz-uuid-eng',
          'title': 'Use of English Diagnostic',
          'subject': 'English Language',
          'total_questions': 60,
          'correct_answers': 48,
          'score_percent': 80,
          'duration_seconds': 2400,
          'completed_at': '2026-10-15T15:00:00Z',
        },
        {
          'id': 'quiz-uuid-chm',
          'title': 'Chemistry Organic Test',
          'subject': 'Chemistry',
          'total_questions': 40,
          'correct_answers': 30,
          'score_percent': 75,
          'duration_seconds': 1800,
          'completed_at': '2026-10-16T09:00:00Z',
        },
      ];

      await service.hydrateFromRemote(
        streakDays: 7,
        xpPoints: 1200,
        remoteQuizzes: remoteQuizzes,
      );

      final hydratedMetrics = service.getQuizPerformanceMetrics();
      expect(hydratedMetrics.totalQuizSessions, 4);
      expect(hydratedMetrics.totalQuestionsAnswered, 180);
      expect(
        hydratedMetrics.subjectAccuracies['mathematics'],
        closeTo(0.80, 0.001),
      );
      expect(hydratedMetrics.subjectAccuracies['physics'], closeTo(0.70, 0.001));
      expect(
        hydratedMetrics.subjectAccuracies['english language'],
        closeTo(0.80, 0.001),
      );
      expect(
        hydratedMetrics.subjectAccuracies['chemistry'],
        closeTo(0.75, 0.001),
      );
      expect(hydratedMetrics.subjectQuestionCounts['physics'], 40);
      expect(hydratedMetrics.overallMockAccuracy, closeTo(0.7625, 0.001));

      // Validate readiness calculation on the clean install
      final readiness = const CbtReadinessCalculator().compute(
        syllabusCoverage: 0.80,
        fsrsRetentionRate: service.getOverallRetentionRate(),
        mockScoreRatio: hydratedMetrics.overallMockAccuracy,
        daysRemaining: 30,
        registeredCourses: const [
          RegisteredCourseInput(
            title: 'Mathematics',
            courseCode: 'MTH',
            syllabusCoverage: 0.80,
          ),
          RegisteredCourseInput(
            title: 'Physics',
            courseCode: 'PHY',
            syllabusCoverage: 0.75,
          ),
          RegisteredCourseInput(
            title: 'English Language',
            courseCode: 'ENG',
            syllabusCoverage: 0.85,
          ),
          RegisteredCourseInput(
            title: 'Chemistry',
            courseCode: 'CHM',
            syllabusCoverage: 0.70,
          ),
        ],
        subjectAccuracies: hydratedMetrics.subjectAccuracies,
        subjectRetentions: hydratedMetrics.subjectRetentions,
        subjectQuestionCounts: hydratedMetrics.subjectQuestionCounts,
        totalQuestionsAnswered: hydratedMetrics.totalQuestionsAnswered,
      );

      expect(readiness.isCalibrated, isTrue);
      expect(readiness.isSampleSufficient, isTrue);
      expect(readiness.totalQuestionsAnswered, 180);
      expect(readiness.projectedTotalScore, greaterThan(250));
      expect(
        readiness.confidenceIntervalLabel,
        contains('Based on 180 questions'),
      );
    });

    test(
        'UserActivityService deduplicates remoteQuizzes against existing local sessions without inflating question volume or score averages',
        () async {
      final inMemory = <String, String>{};
      final storage = MockLocalStorageService();

      when(() => storage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemory[inv.namedArguments[#key] as String]);
      when(
        () => storage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        inMemory[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });

      final service = UserActivityServiceImpl(storage);

      // Record local session
      await service.recordStudySession(
        cardsReviewed: 40,
        durationSeconds: 1800,
        retentionScore: 0.85,
        masteredCards: 34,
        activityCategory: 'quiz',
        subject: 'Physics',
      );

      var metrics = service.getQuizPerformanceMetrics();
      expect(metrics.totalQuizSessions, 1);
      expect(metrics.totalQuestionsAnswered, 40);

      // Remote quiz with matching subject and same timestamp
      final duplicateRemoteQuiz = {
        'id': 'remote-uuid-1',
        'title': 'Physics Exam',
        'subject': 'Physics',
        'total_questions': 40,
        'correct_answers': 34,
        'score_percent': 85,
        'duration_seconds': 1800,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      };

      // Hydrate with duplicate
      await service.hydrateQuizSessions([duplicateRemoteQuiz]);

      metrics = service.getQuizPerformanceMetrics();
      expect(metrics.totalQuizSessions, 1);
      expect(metrics.totalQuestionsAnswered, 40);

      // Add distinct quiz for Chemistry
      final newRemoteQuiz = {
        'id': 'remote-uuid-2',
        'title': 'Chemistry Exam',
        'subject': 'Chemistry',
        'total_questions': 30,
        'correct_answers': 24,
        'score_percent': 80,
        'duration_seconds': 1200,
        'completed_at': '2026-10-10T08:00:00Z',
      };

      await service.hydrateQuizSessions([newRemoteQuiz]);

      metrics = service.getQuizPerformanceMetrics();
      expect(metrics.totalQuizSessions, 2);
      expect(metrics.totalQuestionsAnswered, 70);
    });

    test(
        'UserActivityService fetches from remote automatically when remoteQuizzes is omitted and local sessions are empty',
        () async {
      final inMemory = <String, String>{};
      final storage = MockLocalStorageService();
      final mockDio = MockDio();

      when(() => storage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemory[inv.namedArguments[#key] as String]);
      when(
        () => storage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        inMemory[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });

      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: [
            {
              'id': 'remote-auto-fetch-1',
              'title': 'Biology Mock',
              'subject': 'Biology',
              'total_questions': 50,
              'correct_answers': 40,
              'score_percent': 80,
              'duration_seconds': 2000,
              'completed_at': '2026-10-12T14:00:00Z',
            },
          ],
          statusCode: 200,
          requestOptions: RequestOptions(path: AppApiEndpoint.quizzes),
        ),
      );

      final service = UserActivityServiceImpl(storage, dio: mockDio);
      expect(service.getQuizPerformanceMetrics().totalQuizSessions, 0);

      // Call hydrateFromRemote without remoteQuizzes
      await service.hydrateFromRemote(streakDays: 5, xpPoints: 500);

      final metrics = service.getQuizPerformanceMetrics();
      expect(metrics.totalQuizSessions, 1);
      expect(metrics.totalQuestionsAnswered, 50);
      expect(metrics.subjectAccuracies['biology'], closeTo(0.80, 0.001));
    });

    test(
        'DashboardRemoteDataSourceImpl coordinates quiz hydration during getDashboardFeed on clean install',
        () async {
      final inMemory = <String, String>{};
      final storage = MockLocalStorageService();
      final mockDio = MockDio();
      final mockClient = MockDashboardApiClient();

      when(() => storage.getPreference(key: any(named: 'key')))
          .thenAnswer((inv) => inMemory[inv.namedArguments[#key] as String]);
      when(
        () => storage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((inv) async {
        inMemory[inv.namedArguments[#key] as String] =
            inv.namedArguments[#data] as String;
      });

      final service = UserActivityServiceImpl(storage, dio: mockDio);

      when(
        () => mockDio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
          options: any(named: 'options'),
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          data: [
            {
              'id': 'dashboard-quiz-1',
              'title': 'Government Finals Mock',
              'subject': 'Government',
              'total_questions': 40,
              'correct_answers': 36,
              'score_percent': 90,
              'duration_seconds': 1500,
              'completed_at': '2026-10-13T16:00:00Z',
            },
          ],
          statusCode: 200,
          requestOptions: RequestOptions(path: AppApiEndpoint.quizzes),
        ),
      );

      when(() => mockClient.getDashboardFeed(any())).thenAnswer(
        (_) async => const DashboardFeedModel(
          analyticsSummary: AnalyticsSummaryModel(
            currentStreakDays: 10,
            longestStreakDays: 15,
            weeklyMinutesStudied: 120,
            overallRetentionRate: 0.85,
            totalCardsMastered: 80,
            heatMapData: [],
            xpPoints: 2000,
            academicRank: 'Cortex Pioneer I',
          ),
          dueStudyDecks: [],
          curatedCourses: [
            CuratedCourseModel(
              id: 'course-gov',
              title: 'Government',
              courseCode: 'GOV',
              department: 'Arts & Humanities',
              totalMaterials: 20,
              hasActivePastPapers: true,
              iconName: 'gavel',
              colorHex: '#3B82F6',
              syllabusCoverage: 0.75,
            ),
          ],
        ),
      );

      when(mockClient.getReviewQueue).thenAnswer((_) async => const []);

      final dataSource = DashboardRemoteDataSourceImpl(
        mockClient,
        userActivityService: service,
        storageService: storage,
        dio: mockDio,
      );

      final feed = await dataSource.getDashboardFeed();

      expect(feed.curatedCourses, isNotEmpty);
      final metrics = service.getQuizPerformanceMetrics();
      expect(metrics.totalQuizSessions, 1);
      expect(metrics.totalQuestionsAnswered, 40);
      expect(metrics.subjectAccuracies['government'], closeTo(0.90, 0.001));
    });
  });
}
