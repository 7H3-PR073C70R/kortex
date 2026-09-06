import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/biometric_auth_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  group('BiometricAuthService Background Re-Arming & Timeout Suite', () {
    late MockLocalStorageService mockStorage;
    late MockLocalAuthentication mockLocalAuth;
    late BiometricAuthServiceImpl service;

    setUp(() {
      mockStorage = MockLocalStorageService();
      mockLocalAuth = MockLocalAuthentication();

      when(() => mockStorage.getPreference(key: '__biometric_lock_enabled'))
          .thenReturn('true');
      when(() => mockStorage.getPreference(key: '__biometric_lock_timeout_seconds'))
          .thenReturn(null);

      service = BiometricAuthServiceImpl(
        mockStorage,
        auth: mockLocalAuth,
      );
    });

    test('default background timeout is 30 seconds', () {
      expect(service.backgroundLockTimeout, equals(const Duration(seconds: 30)));
    });

    test('reading persisted timeout returns configured Duration', () {
      when(() => mockStorage.getPreference(key: '__biometric_lock_timeout_seconds'))
          .thenReturn('60');

      expect(service.backgroundLockTimeout, equals(const Duration(seconds: 60)));
    });

    test('setBackgroundLockTimeout persists in seconds', () async {
      when(
        () => mockStorage.savePreference(
          key: '__biometric_lock_timeout_seconds',
          data: '45',
        ),
      ).thenAnswer((_) async {});

      await service.setBackgroundLockTimeout(const Duration(seconds: 45));

      verify(
        () => mockStorage.savePreference(
          key: '__biometric_lock_timeout_seconds',
          data: '45',
        ),
      ).called(1);
    });

    test('recordBackgroundedAt records timestamp and lastBackgroundedAt', () {
      final now = DateTime(2026, 9, 6, 12);
      service.recordBackgroundedAt(now);

      expect(service.lastBackgroundedAt, equals(now));
    });

    test('shouldReArmLock returns false if not enabled', () {
      when(() => mockStorage.getPreference(key: '__biometric_lock_enabled'))
          .thenReturn('false');

      final now = DateTime(2026, 9, 6, 12);
      service.recordBackgroundedAt(now);

      final later = now.add(const Duration(seconds: 40));
      expect(service.shouldReArmLock(now: later), isFalse);
    });

    test('shouldReArmLock returns false if no background timestamp recorded', () {
      expect(service.shouldReArmLock(), isFalse);
    });

    test('shouldReArmLock returns false if elapsed time is below 30s threshold', () {
      final start = DateTime(2026, 9, 6, 12);
      service.recordBackgroundedAt(start);

      final elapsed20s = start.add(const Duration(seconds: 20));
      expect(service.shouldReArmLock(now: elapsed20s), isFalse);
    });

    test('shouldReArmLock returns true once elapsed time reaches or exceeds 30s threshold', () {
      final start = DateTime(2026, 9, 6, 12);
      service.recordBackgroundedAt(start);

      final elapsed30s = start.add(const Duration(seconds: 30));
      expect(service.shouldReArmLock(now: elapsed30s), isTrue);

      final elapsed45s = start.add(const Duration(seconds: 45));
      expect(service.shouldReArmLock(now: elapsed45s), isTrue);
    });

    test('shouldReArmLock respects explicit custom threshold override', () {
      final start = DateTime(2026, 9, 6, 12);
      service.recordBackgroundedAt(start);

      // 10s is under default 30s, but >= custom 10s threshold
      final elapsed10s = start.add(const Duration(seconds: 10));
      expect(
        service.shouldReArmLock(
          threshold: const Duration(seconds: 10),
          now: elapsed10s,
        ),
        isTrue,
      );
    });

    test('clearBackgroundedAt resets recorded timestamp', () {
      service.recordBackgroundedAt(DateTime.now());
      expect(service.lastBackgroundedAt, isNotNull);

      service.clearBackgroundedAt();
      expect(service.lastBackgroundedAt, isNull);
    });
  });
}
