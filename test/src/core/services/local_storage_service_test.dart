import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalStorageServiceImpl service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'existing_key': 'existing_value',
    });
    service = LocalStorageServiceImpl();
    await service.initDB();
  });

  group('LocalStorageService (SharedPreferences) Test Suite', () {
    test('initDB initializes underlying SharedPreferences', () async {
      expect(service.getPreference(key: 'existing_key'), equals('existing_value'));
    });

    test('savePreference stores value and makes it accessible via getPreference', () async {
      await service.savePreference(key: 'theme_mode', data: 'dark');

      expect(service.getPreference(key: 'theme_mode'), equals('dark'));
    });

    test('getPreference returns null for non-existent key', () {
      final result = service.getPreference(key: 'non_existent_key');
      expect(result, isNull);
    });

    test('deletePreference removes key from storage', () async {
      await service.savePreference(key: 'temp_key', data: 'temp_val');
      expect(service.getPreference(key: 'temp_key'), equals('temp_val'));

      await service.deletePreference(key: 'temp_key');
      expect(service.getPreference(key: 'temp_key'), isNull);
    });
  });
}
