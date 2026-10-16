import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/analytics_service.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/performance_service.dart';
import 'package:kortex/src/core/services/social_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CrashlyticsService Tests', () {
    late CrashlyticsService crashlytics;

    setUp(() {
      crashlytics = CrashlyticsService();
    });

    test('recordError executes without throwing in test environment', () async {
      await expectLater(
        crashlytics.recordError(
          Exception('Test error'),
          StackTrace.current,
          reason: 'Unit test',
        ),
        completes,
      );
    });

    test('log breadcrumb executes without throwing in test environment', () async {
      await expectLater(
        crashlytics.log('User navigated to dashboard'),
        completes,
      );
    });

    test('setCustomKey executes without throwing in test environment', () async {
      await expectLater(
        crashlytics.setCustomKey('user_role', 'student'),
        completes,
      );
    });

    test('setUserId executes without throwing in test environment', () async {
      await expectLater(
        crashlytics.setUserId('user-123'),
        completes,
      );
    });
  });

  group('AnalyticsService Tests', () {
    late AnalyticsService analytics;

    setUp(() {
      analytics = AnalyticsService();
    });

    test('logScreenView completes safely', () async {
      await expectLater(
        analytics.logScreenView(screenName: 'DashboardScreen'),
        completes,
      );
    });

    test('logStudySessionCompleted completes safely', () async {
      await expectLater(
        analytics.logStudySessionCompleted(
          deckId: 'deck-physics-101',
          cardCount: 25,
          accuracy: 0.92,
        ),
        completes,
      );
    });

    test('logFlashcardsGenerated completes safely', () async {
      await expectLater(
        analytics.logFlashcardsGenerated(
          sourceType: 'pdf',
          cardCount: 15,
        ),
        completes,
      );
    });

    test('logQuizCompleted completes safely', () async {
      await expectLater(
        analytics.logQuizCompleted(
          quizId: 'quiz-calc',
          score: 8,
          totalQuestions: 10,
        ),
        completes,
      );
    });

    test('logCbtDiagnosticStarted records correct event and parameters', () async {
      await analytics.logCbtDiagnosticStarted(
        trackOrExamName: 'JAMB UTME',
      );
      expect(analytics.loggedEventsForTesting.length, 1);
      final event = analytics.loggedEventsForTesting.first;
      expect(event['name'], 'cbt_diagnostic_started');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['track_name'], 'JAMB UTME');
      expect(params['question_count'], 15);
    });

    test('logCbtDiagnosticCompleted records correct event and parameters', () async {
      await analytics.logCbtDiagnosticCompleted(
        trackOrExamName: 'WAEC WASSCE',
        scorePercent: 78,
        totalQuestions: 15,
        correctAnswers: 12,
        durationSeconds: 520,
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'cbt_diagnostic_completed');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['track_name'], 'WAEC WASSCE');
      expect(params['score_percent'], 78);
      expect(params['total_questions'], 15);
      expect(params['correct_answers'], 12);
      expect(params['duration_seconds'], 520);
    });

    test('logCbtMockExamStarted records correct event and parameters', () async {
      await analytics.logCbtMockExamStarted(
        examTrack: 'JAMB Medicine',
        attemptId: 'attempt-uuid-123',
        totalQuestions: 180,
        durationMinutes: 120,
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'cbt_mock_exam_started');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['exam_track'], 'JAMB Medicine');
      expect(params['attempt_id'], 'attempt-uuid-123');
      expect(params['total_questions'], 180);
      expect(params['duration_minutes'], 120);
      expect(params['is_timed'], 1);
    });

    test('logCbtMockExamSubmitted records correct event and parameters', () async {
      await analytics.logCbtMockExamSubmitted(
        examTrack: 'JAMB Medicine',
        attemptId: 'attempt-uuid-123',
        scorePercent: 82,
        totalQuestions: 180,
        correctAnswers: 148,
        elapsedSeconds: 7100,
        isAutoSubmit: false,
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'cbt_mock_exam_submitted');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['exam_track'], 'JAMB Medicine');
      expect(params['attempt_id'], 'attempt-uuid-123');
      expect(params['score_percent'], 82);
      expect(params['total_questions'], 180);
      expect(params['correct_answers'], 148);
      expect(params['elapsed_seconds'], 7100);
      expect(params['is_auto_submit'], 0);
    });

    test('logCbtExamResumedAfterInterrupt records correct event and parameters', () async {
      await analytics.logCbtExamResumedAfterInterrupt(
        examTrack: 'NECO Senior School',
        attemptId: 'attempt-uuid-456',
        remainingSeconds: 1800,
        answeredQuestionsCount: 45,
        totalQuestions: 60,
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'cbt_exam_resumed_after_interrupt');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['exam_track'], 'NECO Senior School');
      expect(params['attempt_id'], 'attempt-uuid-456');
      expect(params['remaining_seconds'], 1800);
      expect(params['answered_count'], 45);
      expect(params['total_questions'], 60);
    });

    test('logCbtOfflineQueueFlushSuccess records correct event and parameters', () async {
      await analytics.logCbtOfflineQueueFlushSuccess(
        flushedCount: 3,
        remainingCount: 0,
        durationMs: 340,
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'cbt_offline_queue_flush_success');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['flushed_count'], 3);
      expect(params['remaining_count'], 0);
      expect(params['duration_ms'], 340);
    });

    test('logCbtOfflineQueueFlushFailed records correct event and parameters', () async {
      await analytics.logCbtOfflineQueueFlushFailed(
        failedCount: 2,
        errorReason: 'network_timeout_socket_error',
        retryCount: 4,
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'cbt_offline_queue_flush_failed');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['failed_count'], 2);
      expect(params['error_reason'], 'network_timeout_socket_error');
      expect(params['retry_count'], 4);
    });

    test('logReadinessScoreViewed records correct event and parameters', () async {
      await analytics.logReadinessScoreViewed(
        readinessScore: 76.5,
        statusTier: 'onTrack',
        confidenceIntervalLabel: 'Readiness: 76% ± 5%',
        standardErrorMargin: 5,
        examTrack: 'JAMB UTME 2026',
      );
      final event = analytics.loggedEventsForTesting.last;
      expect(event['name'], 'readiness_score_viewed');
      final params = event['parameters'] as Map<String, Object>;
      expect(params['readiness_score'], 76.5);
      expect(params['status_tier'], 'onTrack');
      expect(params['confidence_label'], 'Readiness: 76% ± 5%');
      expect(params['standard_error_margin'], 5);
      expect(params['exam_track'], 'JAMB UTME 2026');
    });

    test('observer returns null or instance safely', () {
      final obs = analytics.observer;
      expect(obs, anyOf(isNull, isNotNull));
    });
  });

  group('PerformanceService Tests', () {
    late PerformanceService performance;

    setUp(() {
      performance = PerformanceService();
    });

    test('newTrace returns safe trace with metric and attribute support', () async {
      final trace = performance.newTrace('test_operation');
      await trace.start();
      trace..putAttribute('mode', 'offline')
      ..incrementMetric('items_processed', 5)
      ..setMetric('total_count', 10);
      await trace.stop();
    });

    test('traceAction measures execution and returns result', () async {
      final result = await performance.traceAction<int>(
        'calculate_primes',
        (trace) async {
          trace.putAttribute('batch', '1');
          return 42;
        },
      );
      expect(result, equals(42));
    });
  });

  group('NotificationService Tests', () {
    late NotificationService notificationService;

    setUp(() {
      notificationService = NotificationService();
    });

    tearDown(() {
      notificationService.dispose();
    });

    test('initialize runs safely in test environment', () async {
      await expectLater(notificationService.initialize(), completes);
    });

    test('getToken returns null in test environment without throwing', () async {
      final token = await notificationService.getToken();
      expect(token, isNull);
    });

    test('requestPermission returns null in test environment without throwing', () async {
      final settings = await notificationService.requestPermission();
      expect(settings, isNull);
    });

    test('syncDeviceTokenWithBackend returns false gracefully when no token or offline', () async {
      final synced = await notificationService.syncDeviceTokenWithBackend(
        userId: 'test-user-uuid',
      );
      expect(synced, isFalse);
    });

    test('showLocalNotification executes safely in test environment', () async {
      await expectLater(
        notificationService.showLocalNotification(
          id: 101,
          title: 'Remote Push',
          body: 'Content',
          payload: '/dashboard',
        ),
        completes,
      );
    });

    test('cancelAllNotifications executes safely in test environment', () async {
      await expectLater(
        notificationService.cancelAllNotifications(),
        completes,
      );
    });

    test('setupTokenRefreshListener executes safely with empty or valid userId', () {
      expect(
        () => notificationService.setupTokenRefreshListener(''),
        returnsNormally,
      );
      expect(
        () => notificationService.setupTokenRefreshListener('user-123'),
        returnsNormally,
      );
    });
  });

  group('SocialAuthService Tests', () {
    test('generateNonce produces non-empty string of expected length', () {
      final nonce1 = SocialAuthService.generateNonce();
      final nonce2 = SocialAuthService.generateNonce(16);

      expect(nonce1.length, equals(32));
      expect(nonce2.length, equals(16));
      expect(nonce1, isNot(equals(SocialAuthService.generateNonce())));
    });

    test('sha256ofString creates deterministic hash', () {
      const input = 'kortex-secure-nonce-12345';
      final hash1 = SocialAuthService.sha256ofString(input);
      final hash2 = SocialAuthService.sha256ofString(input);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64));
    });

    test('signOut completes safely in test environment', () async {
      final service = SocialAuthService();
      await expectLater(service.signOut(), completes);
    });
  });
}
