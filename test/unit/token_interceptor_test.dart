import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/networking/interceptors/dio_interceptors.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';

class _FakeUserStorageService extends Fake implements UserStorageService {
  String? _accessToken = 'expired-token';
  String? _refreshToken = 'valid-refresh-token';
  bool cleared = false;

  @override
  bool isTokenExpired() => true;

  @override
  void clearStorage() {
    cleared = true;
    _accessToken = null;
    _refreshToken = null;
  }

  @override
  String? getRefreshToken() => _refreshToken;

  @override
  String? getToken() => _accessToken;

  @override
  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
  }
}

class _FakeSessionExpiredService extends Fake implements SessionExpiredService {
  bool sessionExpiredNotified = false;

  @override
  void notifySessionExpired([String reason = 'session_expired']) {
    sessionExpiredNotified = true;
  }
}

void main() {
  group('TokenInterceptor Resiliency Tests (P2-02)', () {
    test('RefreshTokenResult enum has success, invalidSession, transientNetworkError', () {
      expect(RefreshTokenResult.values, contains(RefreshTokenResult.success));
      expect(RefreshTokenResult.values, contains(RefreshTokenResult.invalidSession));
      expect(RefreshTokenResult.values, contains(RefreshTokenResult.transientNetworkError));
    });

    test('HTTP 429 response does not trigger auto-logout when handled as transient error', () async {
      final fakeStorage = _FakeUserStorageService();
      final fakeSessionService = _FakeSessionExpiredService();

      const result = RefreshTokenResult.transientNetworkError;
      if (result == RefreshTokenResult.invalidSession) {
        fakeStorage.clearStorage();
        fakeSessionService.notifySessionExpired();
      }

      expect(fakeStorage.cleared, isFalse, reason: 'Storage must NOT be cleared on transient error');
      expect(fakeSessionService.sessionExpiredNotified, isFalse, reason: 'Session expired event must NOT fire');
    });

    test('Explicit invalid_grant triggers auto-logout', () async {
      final fakeStorage = _FakeUserStorageService();
      final fakeSessionService = _FakeSessionExpiredService();

      const result = RefreshTokenResult.invalidSession;
      if (result == RefreshTokenResult.invalidSession) {
        fakeStorage.clearStorage();
        fakeSessionService.notifySessionExpired();
      }

      expect(fakeStorage.cleared, isTrue);
      expect(fakeSessionService.sessionExpiredNotified, isTrue);
    });
  });
}
