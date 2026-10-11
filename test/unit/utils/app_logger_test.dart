import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:mocktail/mocktail.dart';

class MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  group('AppLogger Unit Test Suite', () {
    late MockCrashlyticsService mockCrashlytics;

    setUp(() async {
      mockCrashlytics = MockCrashlyticsService();
      if (locator.isRegistered<CrashlyticsService>()) {
        await locator.unregister<CrashlyticsService>();
      }
    });

    tearDown(() async {
      if (locator.isRegistered<CrashlyticsService>()) {
        await locator.unregister<CrashlyticsService>();
      }
    });

    test('debug, info, and warning execute without throwing', () {
      expect(() => AppLogger.debug('Debug test message', tag: 'Test'), returnsNormally);
      expect(() => AppLogger.info('Info test message', tag: 'Test'), returnsNormally);
      expect(() => AppLogger.warning('Warning test message', tag: 'Test'), returnsNormally);
    });

    test('recordNonFatal safely handles unregistered CrashlyticsService without throwing', () {
      final testError = StateError('Test unhandled state error');
      final testStack = StackTrace.current;

      expect(
        () => AppLogger.recordNonFatal(testError, testStack, reason: 'Unit test execution'),
        returnsNormally,
      );
    });

    test('recordNonFatal forwards error and stackTrace to registered CrashlyticsService', () async {
      locator.registerSingleton<CrashlyticsService>(mockCrashlytics);

      when(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace>(),
          reason: any<String>(named: 'reason'),
          information: any<Iterable<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});

      const testError = FormatException('Invalid JSON payload');
      final testStack = StackTrace.current;

      AppLogger.recordNonFatal(
        testError,
        testStack,
        reason: 'Sync decode failure',
      );

      // Allow unawaited future to execute
      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(
        () => mockCrashlytics.recordError(
          testError,
          testStack,
          reason: 'Sync decode failure',
          information: any<Iterable<Object>>(named: 'information'),
        ),
      ).called(1);
    });

    test('error method dispatches non-fatal error when recordCrashlytics is true', () async {
      locator.registerSingleton<CrashlyticsService>(mockCrashlytics);

      when(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace>(),
          reason: any<String>(named: 'reason'),
          information: any<Iterable<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      ).thenAnswer((_) async {});

      final testError = Exception('Critical payment timeout');
      final testStack = StackTrace.current;

      AppLogger.error(
        'Payment gateway timed out',
        tag: 'Payments',
        error: testError,
        stackTrace: testStack,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      verify(
        () => mockCrashlytics.recordError(
          testError,
          testStack,
          reason: 'Payment gateway timed out',
          information: any<Iterable<Object>>(named: 'information'),
        ),
      ).called(1);
    });

    test('error method skips crashlytics dispatch when recordCrashlytics is false', () async {
      locator.registerSingleton<CrashlyticsService>(mockCrashlytics);

      final testError = Exception('Expected validation failure');
      final testStack = StackTrace.current;

      AppLogger.error(
        'Expected validation error',
        tag: 'Validation',
        error: testError,
        stackTrace: testStack,
        recordCrashlytics: false,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      verifyNever(
        () => mockCrashlytics.recordError(
          any<dynamic>(),
          any<StackTrace>(),
          reason: any<String>(named: 'reason'),
          information: any<Iterable<Object>>(named: 'information'),
          fatal: any<bool>(named: 'fatal'),
        ),
      );
    });
  });
}
