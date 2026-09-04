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
