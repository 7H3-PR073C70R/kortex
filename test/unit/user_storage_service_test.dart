import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';

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

void main() {
  late _FakeLocalStorageService fakeStorage;
  late UserStorageServiceImpl userStorage;

  setUp(() {
    fakeStorage = _FakeLocalStorageService();
    userStorage = UserStorageServiceImpl(fakeStorage);
  });

  group('UserStorageService Pro Subscription & Entitlement Suite', () {
    test('isProSubscriber returns false by default when unset', () {
      expect(userStorage.isProSubscriber(), isFalse);
    });

    test('saveProStatus persists pro status as true and retrieves it', () async {
      await userStorage.saveProStatus(isPro: true);

      expect(fakeStorage.getPreference(key: PrefKeys.isProSubscriber), equals('true'));
      expect(userStorage.isProSubscriber(), isTrue);
    });

    test('saveProStatus updates pro status to false on subscription downgrade', () async {
      await userStorage.saveProStatus(isPro: true);
      expect(userStorage.isProSubscriber(), isTrue);

      await userStorage.saveProStatus(isPro: false);
      expect(fakeStorage.getPreference(key: PrefKeys.isProSubscriber), equals('false'));
      expect(userStorage.isProSubscriber(), isFalse);
    });

    test('clearStorage removes tokens and pro subscription status', () async {
      await userStorage.saveToken('test_jwt_token');
      await userStorage.saveRefreshToken('test_refresh_token');
      await userStorage.saveProStatus(isPro: true);

      expect(userStorage.isProSubscriber(), isTrue);
      expect(userStorage.getToken(), equals('test_jwt_token'));

      userStorage.clearStorage();

      expect(userStorage.isProSubscriber(), isFalse);
      expect(userStorage.getToken(), isNull);
      expect(userStorage.getRefreshToken(), isNull);
    });
  });
}
