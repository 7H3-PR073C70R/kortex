import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockLocalStorageService mockLocalStorageService;
  late MockFlutterSecureStorage mockSecureStorage;
  late UserStorageService userStorageService;

  setUp(() {
    mockLocalStorageService = MockLocalStorageService();
    mockSecureStorage = MockFlutterSecureStorage();

    when(() => mockSecureStorage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => mockSecureStorage.write(key: any(named: 'key'), value: any(named: 'value')))
        .thenAnswer((_) async {});
    when(() => mockSecureStorage.delete(key: any(named: 'key')))
        .thenAnswer((_) async {});
    when(() => mockLocalStorageService.getPreference(key: any(named: 'key')))
        .thenReturn(null);
    when(() => mockLocalStorageService.savePreference(key: any(named: 'key'), data: any(named: 'data')))
        .thenAnswer((_) async => true);
    when(() => mockLocalStorageService.deletePreference(key: any(named: 'key')))
        .thenAnswer((_) async => true);

    userStorageService = UserStorageServiceImpl(
      mockLocalStorageService,
      secureStorage: mockSecureStorage,
    );
  });

  test('saveToken writes strictly to secure storage and deletes any legacy local pref', () async {
    const dummyJwt = 'header.payload.signature';
    await userStorageService.saveToken(dummyJwt);

    verify(() => mockSecureStorage.write(key: '__token', value: dummyJwt)).called(1);
    verify(() => mockLocalStorageService.deletePreference(key: '__token')).called(greaterThanOrEqualTo(1));
  });

  test('saveRefreshToken writes strictly to secure storage', () async {
    const dummyRefresh = 'sample_refresh_token_123';
    await userStorageService.saveRefreshToken(dummyRefresh);

    verify(() => mockSecureStorage.write(key: '__refresh_token', value: dummyRefresh)).called(1);
    verify(() => mockLocalStorageService.deletePreference(key: '__refresh_token')).called(greaterThanOrEqualTo(1));
  });
}
