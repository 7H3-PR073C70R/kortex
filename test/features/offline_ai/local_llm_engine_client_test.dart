import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLocalStorageService mockStorage;
  late LocalLlmEngineClient client;

  setUpAll(() async {
    mockStorage = MockLocalStorageService();
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(mockStorage);
  });

  setUp(() {
    client = LocalLlmEngineClient();
  });

  group('LocalLlmEngineClient Offline Generation & Error Handling', () {
    test('isModelDownloaded returns false when file does not exist on disk', () {
      when(() => mockStorage.getPreference(key: '__local_llm_model_downloaded'))
          .thenReturn('true');
      when(() => mockStorage.getPreference(key: '__local_llm_model_path'))
          .thenReturn('/non/existent/path/model.gguf');

      expect(client.isModelDownloaded, isFalse);
    });

    test('generate throws LocalLlmNotDownloadedException when model is not downloaded on device', () async {
      when(() => mockStorage.getPreference(key: '__local_llm_model_downloaded'))
          .thenReturn(null);
      when(() => mockStorage.getPreference(key: '__local_llm_model_path'))
          .thenReturn(null);

      expect(
        client.generate(
          prompt: 'Explain interjection in depth',
          systemInstruction: 'Be helpful.',
        ),
        emitsError(isA<LocalLlmNotDownloadedException>()),
      );
    });

    test('generate does not provide hardcoded fallback when model is not downloaded', () async {
      when(() => mockStorage.getPreference(key: '__local_llm_model_downloaded'))
          .thenReturn(null);
      when(() => mockStorage.getPreference(key: '__local_llm_model_path'))
          .thenReturn(null);

      expect(
        client.generate(
          prompt: 'Explain pronouns',
          systemInstruction: 'Be helpful.',
        ),
        emitsError(isA<LocalLlmNotDownloadedException>().having(
          (e) => e.message,
          'message',
          contains('downloaded'),
        )),
      );
    });
  });
}
