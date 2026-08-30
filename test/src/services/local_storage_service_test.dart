import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:kortex/src/services/local_storage_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHive extends Mock implements HiveInterface {}

class MockBox extends Mock implements Box<String> {}

void main() {
  late MockHive mockHive;
  late MockBox mockBox;
  late LocalStorageServiceImpl service;

  setUp(() {
    mockHive = MockHive();
    mockBox = MockBox();
    service = LocalStorageServiceImpl(hive: mockHive);
  });
  group('local storage service ...', () {
    test('initDB opens Hive box', () async {
      when(
        () => mockHive.openBox<String>('kortex_app_box'),
      ).thenAnswer((_) async => mockBox);

      await service.initDB();

      verify(() => mockHive.openBox<String>('kortex_app_box')).called(1);
    });

    test('savePreference calls put on box', () async {
      service.setBox(mockBox);
      when(() => mockBox.put('key', 'value')).thenAnswer((_) async {});

      await service.savePreference(key: 'key', data: 'value');

      verify(() => mockBox.put('key', 'value')).called(1);
    });

    test('getPreference retrieves value', () {
      service.setBox(mockBox);
      when(() => mockBox.get('key')).thenReturn('value');

      final result = service.getPreference(key: 'key');
      expect(result, equals('value'));
    });

    test('deletePreference deletes key', () async {
      service.setBox(mockBox);
      when(() => mockBox.delete('key')).thenAnswer((_) async {});

      await service.deletePreference(key: 'key');

      verify(() => mockBox.delete('key')).called(1);
    });
  });
}
