import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_local_data_source.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/repositories/syllabot_repository_impl.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:mocktail/mocktail.dart';

class MockSyllabotLocalDataSource extends Mock implements SyllabotLocalDataSource {}
class MockSyllabotRemoteDataSource extends Mock implements SyllabotRemoteDataSource {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Syllabot Multi-Turn Cumulative Deck Synthesis Test Suite', () {
    late SyllabotRepositoryImpl repository;
    late MockSyllabotLocalDataSource mockLocalDataSource;
    late MockSyllabotRemoteDataSource mockRemoteDataSource;

    setUp(() {
      mockLocalDataSource = MockSyllabotLocalDataSource();
      mockRemoteDataSource = MockSyllabotRemoteDataSource();
      repository = SyllabotRepositoryImpl(
        localDataSource: mockLocalDataSource,
        remoteDataSource: mockRemoteDataSource,
      );
    });

    test('generateDeckFromChat synthesizes cards across multiple turns of AI responses', () async {
      final messages = [
        ChatMessageEntity(
          id: '1',
          sessionId: 'sess_1',
          sender: MessageSender.user,
          text: 'Noun',
          timestamp: DateTime.now(),
          engineType: ExecutionEngineType.localOnDevice,
        ),
        ChatMessageEntity(
          id: '2',
          sessionId: 'sess_1',
          sender: MessageSender.syllabot,
          text: 'A **noun** is a part of speech that names a person, place, thing, or idea.\n\n'
              '### 1. Key Categories:\n'
              '• **Common Noun**: A general name for any person, place, or thing (e.g., city, student).\n'
              '• **Proper Noun**: Specific official names of people, places, or entities (e.g., Paris, Newton).\n'
              '• **Abstract Noun**: Concepts or qualities not perceptible by senses (e.g., entropy, courage).',
          timestamp: DateTime.now(),
          engineType: ExecutionEngineType.localOnDevice,
        ),
        ChatMessageEntity(
          id: '3',
          sessionId: 'sess_1',
          sender: MessageSender.user,
          text: 'How many part of speech do we have?',
          timestamp: DateTime.now(),
          engineType: ExecutionEngineType.localOnDevice,
        ),
        ChatMessageEntity(
          id: '4',
          sessionId: 'sess_1',
          sender: MessageSender.syllabot,
          text: 'There are **8 traditional parts of speech** in English:\n\n'
              '1. **Verb**: Words denoting actions, occurrences, or states of being.\n'
              '2. **Adjective**: Words that describe or qualify nouns or pronouns.\n'
              '3. **Adverb**: Words modifying verbs, adjectives, or other adverbs.',
          timestamp: DateTime.now(),
          engineType: ExecutionEngineType.localOnDevice,
        ),
      ];

      final result = await repository.generateDeckFromChat(
        sessionId: 'sess_1',
        deckTitle: 'Parts of Speech & Grammar',
        courseCode: 'ENG 101',
        messages: messages,
      );

      expect(result.isRight, isTrue);
      result.fold(
        (failure) => fail('Expected Right but got $failure'),
        (deck) {
          expect(deck.title, 'Parts of Speech & Grammar');
          expect(deck.courseCode, 'ENG 101');
          expect(deck.cards.length, greaterThanOrEqualTo(4));

          // Verify cards are drawn from BOTH turn 1 (nouns) AND turn 2 (parts of speech: verbs/adjectives)
          final frontTexts = deck.cards.map((c) => c.front.toLowerCase()).join(' ');
          expect(frontTexts.contains('noun') || frontTexts.contains('common') || frontTexts.contains('abstract'), isTrue);
          expect(frontTexts.contains('verb') || frontTexts.contains('adjective') || frontTexts.contains('adverb'), isTrue);

          // Verify question formulations are standalone and natural
          for (final card in deck.cards) {
            expect(card.front.isNotEmpty, isTrue);
            expect(card.back.isNotEmpty, isTrue);
            // Should not append awkward 'in $deckTitle?' suffix
            expect(card.front.contains('in Parts of Speech & Grammar?'), isFalse);
          }
        },
      );
    });
  });

  group('LocalLlmEngineClient Dynamic Fallback & Robustness Test Suite', () {
    late LocalLlmEngineClient client;

    setUp(() {
      client = LocalLlmEngineClient();
    });

    test('generate yields direct 8-parts-of-speech answer for count query', () async {
      final stream = client.generate(
        prompt: 'How many part of speech do we have?',
        systemInstruction: '',
        socraticMode: SocraticMode.directAnswer,
      );

      final tokens = await stream.toList();
      final fullResponse = tokens.join();

      expect(fullResponse.contains('8 traditional parts of speech') || fullResponse.contains('8'), isTrue);
      expect(fullResponse.contains('Noun'), isTrue);
      expect(fullResponse.contains('Verb'), isTrue);
      expect(fullResponse.contains('Adjective'), isTrue);
      expect(fullResponse.contains('Preposition'), isTrue);
      expect(fullResponse.length, greaterThan(100));
    });
  });
}
