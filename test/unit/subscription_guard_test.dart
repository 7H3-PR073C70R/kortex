import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';

class _FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => _store[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _store[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _store.remove(key);
  }
}

class _FakeUserStorageService implements UserStorageService {
  bool _pro = false;

  @override
  Future<void> initStorage() async {}

  @override
  bool isProSubscriber() => _pro;

  @override
  Future<void> saveProStatus({required bool isPro}) async {
    _pro = isPro;
  }

  @override
  void clearStorage() {
    _pro = false;
  }

  @override
  String? getRefreshToken() => null;

  @override
  String? getToken() => null;

  @override
  String? getUserAvatarUrl() => null;

  @override
  String? getUserDisplayName() => null;

  @override
  String? getUserId() => 'test_user_id';

  @override
  String? getUserEmail() => null;

  @override
  Future<void> saveUserEmail(String email) async {}

  @override
  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {}

  @override
  Future<void> saveRefreshToken(String refreshToken) async {}

  @override
  Future<void> saveToken(String token) async {}
}

void main() {
  late _FakeLocalStorageService fakeLocal;
  late _FakeUserStorageService fakeUser;
  late SubscriptionGuard guard;

  setUp(() {
    fakeLocal = _FakeLocalStorageService();
    fakeUser = _FakeUserStorageService();
    guard = SubscriptionGuard(
      userStorageService: fakeUser,
      localStorageService: fakeLocal,
    );
  });

  group('SubscriptionGuard Entitlement & Feature Gating Suite', () {
    test('isPro reflects false for free users and true for pro users', () async {
      expect(guard.isPro, isFalse);

      await fakeUser.saveProStatus(isPro: true);
      expect(guard.isPro, isTrue);
    });

    test('Cloud AI access is strictly gated behind Pro (Local AI is free)', () async {
      expect(guard.canAccessCloudAi(), isFalse);

      await fakeUser.saveProStatus(isPro: true);
      expect(guard.canAccessCloudAi(), isTrue);
    });

    test('File size limits: 50MB for free, 200MB for Pro', () async {
      const under50Mb = 45 * 1024 * 1024;
      const over50Mb = 65 * 1024 * 1024;
      const over200Mb = 210 * 1024 * 1024;

      // Free user
      expect(guard.canUploadFileSize(under50Mb), isTrue);
      expect(guard.canUploadFileSize(over50Mb), isFalse);
      expect(guard.canUploadFileSize(over200Mb), isFalse);

      // Pro user
      await fakeUser.saveProStatus(isPro: true);
      expect(guard.canUploadFileSize(under50Mb), isTrue);
      expect(guard.canUploadFileSize(over50Mb), isTrue);
      expect(guard.canUploadFileSize(over200Mb), isFalse);
    });

    test('Daily upload limits: 3 for free users, unlimited for Pro', () async {
      const testFile = 10 * 1024 * 1024;

      expect(guard.canUploadDocument(fileSizeBytes: testFile), isTrue);
      await guard.recordDocumentUpload();
      expect(guard.getTodayUploadCount(), equals(1));

      await guard.recordDocumentUpload();
      expect(guard.getTodayUploadCount(), equals(2));

      await guard.recordDocumentUpload();
      expect(guard.getTodayUploadCount(), equals(3));

      // 4th upload should be blocked on free tier
      expect(guard.canUploadDocument(fileSizeBytes: testFile), isFalse);

      // Upgrade to Pro: 4th upload is allowed
      await fakeUser.saveProStatus(isPro: true);
      expect(guard.canUploadDocument(fileSizeBytes: testFile), isTrue);
    });

    test('Deck export gating: CSV free, Anki and Printable PDF Pro', () async {
      expect(guard.canExportDeck(DeckExportFormat.csv), isTrue);
      expect(guard.canExportDeck(DeckExportFormat.anki), isFalse);
      expect(guard.canExportDeck(DeckExportFormat.pdfPrintable), isFalse);

      await fakeUser.saveProStatus(isPro: true);
      expect(guard.canExportDeck(DeckExportFormat.csv), isTrue);
      expect(guard.canExportDeck(DeckExportFormat.anki), isTrue);
      expect(guard.canExportDeck(DeckExportFormat.pdfPrintable), isTrue);
    });

    test('LMS course sync: 1 for free, unlimited for Pro', () async {
      expect(guard.canSyncMultipleLmsCourses(0), isTrue);
      expect(guard.canSyncMultipleLmsCourses(1), isFalse);

      await fakeUser.saveProStatus(isPro: true);
      expect(guard.canSyncMultipleLmsCourses(1), isTrue);
      expect(guard.canSyncMultipleLmsCourses(5), isTrue);
    });

    test('AI Diagnostics is gated behind Pro', () async {
      expect(guard.canAccessAiDiagnostics(), isFalse);

      await fakeUser.saveProStatus(isPro: true);
      expect(guard.canAccessAiDiagnostics(), isTrue);
    });
  });
}
