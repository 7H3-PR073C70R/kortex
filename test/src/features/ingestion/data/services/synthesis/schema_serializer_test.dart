import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';

void main() {
  const serializer = SchemaSerializer();

  group('SchemaSerializer - Layer 4', () {
    test('emits valid JSON conforming to PedagogicalDeckSchema', () {
      final candidates = [
        const PedagogicalCandidateCard(
          front: 'In Cellular Respiration, what does Glycolysis split?',
          back:
              'Glycolysis splits one glucose molecule into two molecules of pyruvate.',
          type: CognitiveQuestionType.svo,
          sourceTopic: 'Glycolysis',
        ),
        const PedagogicalCandidateCard(
          front: 'In Flutter, how does the engine compile code?',
          back: 'Flutter compiles code by invoking the AOT compiler.',
          type: CognitiveQuestionType.mechanism,
          sourceTopic: 'Architecture',
        ),
      ];

      final deck = serializer.serializeDeck(
        deckId: 'deck_123',
        deckTitle: 'Cellular Respiration and Architecture',
        subject: 'General Science',
        category: 'Study',
        candidateCards: candidates,
      );

      final jsonMap = deck.toJson();
      expect(jsonMap['schema_version'], equals('1.0.0'));
      expect(jsonMap['deck_id'], equals('deck_123'));
      expect(jsonMap['cards'], isA<List<dynamic>>());
      final cardsList = (jsonMap['cards'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(cardsList.length, equals(2));

      final firstCard = cardsList.first;
      expect(firstCard['id'], isNotEmpty);
      expect(firstCard['deck_id'], equals('deck_123'));
      expect(firstCard['front'], isNotEmpty);
      expect(firstCard['back'], isNotEmpty);
      expect(firstCard['cognitive_type'], equals('svo'));
      expect(firstCard['fsrs'], isA<Map<String, dynamic>>());
      final fsrsMap = firstCard['fsrs'] as Map<String, dynamic>;
      expect(fsrsMap['stability'], equals(0.0));

      final prettyJson = deck.toPrettyJson();
      expect(jsonDecode(prettyJson), isNotNull);
    });

    test('rejects truncated thoughts in card backs', () {
      final candidates = [
        const PedagogicalCandidateCard(
          front: 'What is the MVP principle?',
          back: 'This principle suggests that you',
          type: CognitiveQuestionType.definition,
          sourceTopic: 'MVP',
        ),
      ];

      final deck = serializer.serializeDeck(
        deckId: 'deck_123',
        deckTitle: 'Test Deck',
        subject: 'Dev',
        category: 'Study',
        candidateCards: candidates,
      );

      expect(deck.cards.isEmpty, isTrue);
    });
  });
}
