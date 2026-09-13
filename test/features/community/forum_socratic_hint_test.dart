import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockLocalStorageService mockStorage;
  late LocalLlmEngineClient localClient;

  setUpAll(() async {
    mockStorage = MockLocalStorageService();
    if (locator.isRegistered<LocalStorageService>()) {
      await locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(mockStorage);
  });

  setUp(() {
    localClient = LocalLlmEngineClient();
  });

  group('Syllabot Socratic Hint Generation Tests', () {
    test('Local LLM hint generation requires downloaded model and throws LocalLlmNotDownloadedException otherwise', () async {
      when(() => mockStorage.getPreference(key: '__local_llm_model_downloaded'))
          .thenReturn(null);
      when(() => mockStorage.getPreference(key: '__local_llm_model_path'))
          .thenReturn(null);

      const prompt =
          'You are Syllabot. A student in track "WAEC - Sciences" (Physics) posted: '
          'Need help: A catapult is used to project a stone. Which of the parameters determines its range?';

      expect(
        localClient.generate(
          prompt: prompt,
          systemInstruction: 'Provide a high-yield Socratic hint.',
        ),
        emitsError(isA<LocalLlmNotDownloadedException>()),
      );
    });
  });
}
