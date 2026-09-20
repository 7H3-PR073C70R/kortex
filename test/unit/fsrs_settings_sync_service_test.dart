import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/models/fsrs_user_settings.dart';
import 'package:kortex/src/features/decks/domain/services/fsrs_settings_sync_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

class MockDio extends Mock implements Dio {}

void main() {
  late MockLocalStorageService mockStorage;
  late MockDio mockDio;
  late FsrsSettingsSyncService syncService;

  setUp(() async {
    mockStorage = MockLocalStorageService();
    mockDio = MockDio();

    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    if (locator.isRegistered<Dio>()) {
      await locator.unregister<Dio>();
    }

    locator
      ..registerSingleton<LocalStorageService>(mockStorage)
      ..registerSingleton<Dio>(mockDio);

    syncService = const FsrsSettingsSyncService();
  });

  tearDown(() async {
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    if (locator.isRegistered<Dio>()) {
      await locator.unregister<Dio>();
    }
  });

  group('FsrsSettingsSyncService Test Suite', () {
    test('load() returns default settings when no preferences stored', () {
      when(() => mockStorage.getPreference(key: FsrsUserSettings.storageKey))
          .thenReturn(null);

      final settings = syncService.load();
      expect(settings.desiredRetention, equals(0.90));
      expect(settings.preferredReminderHour, equals(19));
      expect(settings.preferredReminderMinute, equals(0));
    });

    test('load() parses persisted JSON correctly', () {
      const stored = FsrsUserSettings(
        desiredRetention: 0.85,
        preferredReminderHour: 20,
        preferredReminderMinute: 30,
      );
      when(() => mockStorage.getPreference(key: FsrsUserSettings.storageKey))
          .thenReturn(jsonEncode(stored.toJson()));

      final loaded = syncService.load();
      expect(loaded.desiredRetention, equals(0.85));
      expect(loaded.preferredReminderHour, equals(20));
      expect(loaded.preferredReminderMinute, equals(30));
    });

    test('save() writes to local storage and syncs to Supabase RPC', () async {
      when(
        () => mockStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => true);

      when(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      ).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/rpc'),
          statusCode: 200,
        ),
      );

      const toSave = FsrsUserSettings(
        desiredRetention: 0.95,
        preferredReminderHour: 8,
        preferredReminderMinute: 15,
      );

      final success = await syncService.save(toSave);
      expect(success, isTrue);

      verify(
        () => mockStorage.savePreference(
          key: FsrsUserSettings.storageKey,
          data: jsonEncode(toSave.toJson()),
        ),
      ).called(1);

      verify(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      ).called(1);
    });

    test('save() skips remote sync when syncRemote is false', () async {
      when(
        () => mockStorage.savePreference(
          key: any(named: 'key'),
          data: any(named: 'data'),
        ),
      ).thenAnswer((_) async => true);

      const toSave = FsrsUserSettings(
        desiredRetention: 0.92,
        preferredReminderHour: 21,
      );

      final success = await syncService.save(toSave, syncRemote: false);
      expect(success, isTrue);

      verify(
        () => mockStorage.savePreference(
          key: FsrsUserSettings.storageKey,
          data: jsonEncode(toSave.toJson()),
        ),
      ).called(1);

      verifyNever(
        () => mockDio.post<dynamic>(
          any(),
          data: any(named: 'data'),
        ),
      );
    });
  });
}
