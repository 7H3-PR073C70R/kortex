import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalStorageService mockStorage;
  late LocalLlmEngineClient client;

  setUpAll(() {
    mockStorage = MockLocalStorageService();
    if (locator.isRegistered<LocalStorageService>()) {
      locator.unregister<LocalStorageService>();
    }
    locator.registerSingleton<LocalStorageService>(mockStorage);
  });

  setUp(() {
    client = LocalLlmEngineClient();
  });

  group('LocalLlmEngineClient Offline Generation & Context Awareness', () {
    test('isModelDownloaded returns false when file does not exist on disk', () {
      when(() => mockStorage.getPreference(key: '__local_llm_model_downloaded'))
          .thenReturn('true');
      when(() => mockStorage.getPreference(key: '__local_llm_model_path'))
          .thenReturn('/non/existent/path/model.gguf');

      expect(client.isModelDownloaded, isFalse);
    });

    test('generate provides comprehensive interjection explanation without dummy template', () async {
      final stream = client.generate(
        prompt: 'Explain interjection in dept',
        systemInstruction: 'Be helpful.',
        socraticMode: SocraticMode.stepByStep,
      );

      final tokens = await stream.toList();
      final fullText = tokens.join('');

      expect(fullText, contains('interjection'));
      expect(fullText, contains('Emotive'));
      expect(fullText, contains('Eureka!'));
      expect(fullText, contains('Ouch!'));
      expect(fullText, isNot(contains('Let us analyze "Explain interjection in dept" from first principles')));
    });

    test('generate recognizes contextHistory when asked for examples of all 8', () async {
      final history = [
        ChatMessageEntity(
          id: 'msg_1',
          sessionId: 's1',
          sender: MessageSender.user,
          text: 'What is part of speech',
          timestamp: DateTime.now(),
          engineType: ExecutionEngineType.localOnDevice,
        ),
        ChatMessageEntity(
          id: 'msg_2',
          sessionId: 's1',
          sender: MessageSender.syllabot,
          text: 'The parts of speech are the primary grammatical categories...',
          timestamp: DateTime.now(),
          engineType: ExecutionEngineType.localOnDevice,
        ),
      ];

      final stream = client.generate(
        prompt: 'Given me example of all 8 of them and explain In details',
        systemInstruction: 'Be helpful.',
        socraticMode: SocraticMode.stepByStep,
        contextHistory: history,
      );

      final tokens = await stream.toList();
      final fullText = tokens.join('');

      expect(fullText, contains('8 Parts of Speech'));
      expect(fullText, contains('Noun'));
      expect(fullText, contains('Pronoun'));
      expect(fullText, contains('Verb'));
      expect(fullText, contains('Adjective'));
      expect(fullText, contains('Adverb'));
      expect(fullText, contains('Preposition'));
      expect(fullText, contains('Conjunction'));
      expect(fullText, contains('Interjection'));
    });

    test('generate explains pronouns with categories and examples', () async {
      final stream = client.generate(
        prompt: 'Explain pronouns',
        systemInstruction: 'Be helpful.',
      );

      final tokens = await stream.toList();
      final fullText = tokens.join('');

      expect(fullText, contains('pronoun'));
      expect(fullText, contains('Personal'));
      expect(fullText, contains('Possessive'));
    });

    test('generate explains conjunctions with FANBOYS coordinating conjunctions', () async {
      final stream = client.generate(
        prompt: 'Explain conjunctions',
        systemInstruction: 'Be helpful.',
      );

      final tokens = await stream.toList();
      final fullText = tokens.join('');

      expect(fullText, contains('conjunction'));
      expect(fullText, contains('FANBOYS'));
    });
  });
}
