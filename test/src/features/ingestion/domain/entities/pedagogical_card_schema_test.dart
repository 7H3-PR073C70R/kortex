import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

void main() {
  group('PedagogicalCardSchema & SchemaSerializer Tests', () {
    final fixedClockTime = DateTime.utc(2026, 10, 10, 12);
    final mockClock = FrozenClock(fixedClockTime);
    final serializer = SchemaSerializer(clock: mockClock);

    test('CardSource roundtrip JSON serialization maintains exact coordinates and hierarchy', () {
      const source = CardSource(
        docId: 'doc_hash_12345',
        page: 3,
        sectionPath: ['Chapter 2: Concurrency', 'Section 2.1: Isolates'],
        blockId: 'block_code_99',
        bbox: BoundingBox(left: 10, top: 20, right: 300, bottom: 450),
      );

      final json = source.toJson();
      final restored = CardSource.fromJson(json);

      expect(restored.docId, equals('doc_hash_12345'));
      expect(restored.page, equals(3));
      expect(restored.sectionPath, equals(['Chapter 2: Concurrency', 'Section 2.1: Isolates']));
      expect(restored.blockId, equals('block_code_99'));
      expect(restored.bbox?.left, equals(10.0));
      expect(restored.bbox?.width, equals(290.0));
    });

    test('CardAsset supports all multi-modal asset types with roundtrip fidelity', () {
      final assets = [
        const CardAsset(
          id: 'asset_img_1',
          type: CardAssetType.image,
          content: 'https://kortex.app/assets/photosynthesis.png',
          label: 'Figure 1: Chloroplast Architecture',
        ),
        const CardAsset(
          id: 'asset_math_1',
          type: CardAssetType.latexEquation,
          content: 'E = mc^2',
          label: 'Mass-energy equivalence',
        ),
        const CardAsset(
          id: 'asset_code_1',
          type: CardAssetType.syntaxCode,
          content: 'void main() => print("Hello");',
          mimeType: 'text/x-dart',
        ),
        const CardAsset(
          id: 'asset_diag_1',
          type: CardAssetType.diagram,
          content: 'graph TD; A-->B;',
          label: 'State diagram',
        ),
      ];

      for (final asset in assets) {
        final json = asset.toJson();
        final restored = CardAsset.fromJson(json);
        expect(restored.id, equals(asset.id));
        expect(restored.type, equals(asset.type));
        expect(restored.content, equals(asset.content));
        expect(restored.label, equals(asset.label));
      }
    });

    test('FrozenClock guarantees deterministic UTC timestamps for cards and decks', () {
      const candidate = PedagogicalCandidateCard(
        front: 'What is the role of ATP in cellular metabolism?',
        back: 'ATP serves as the primary energy currency for cellular reactions.',
        type: CognitiveQuestionType.definition,
        sourceTopic: 'Biology',
        source: CardSource(
          docId: 'bio_doc',
          page: 1,
          sectionPath: ['Cellular Respiration', 'Energy Transfer'],
          blockId: 'para_1',
        ),
      );

      final deck = serializer.serializeDeck(
        deckId: 'deck_bio',
        deckTitle: 'Cellular Respiration',
        subject: 'Biology',
        category: 'Science',
        candidateCards: [candidate],
      );

      expect(deck.generatedAt, equals(fixedClockTime));
      expect(deck.cards.first.createdAt, equals(fixedClockTime));
      expect(deck.cards.first.createdAt.isUtc, isTrue);
    });

    test('Deterministic card ID generation produces stable and distinct UUID hashes', () {
      final id1 = SchemaSerializer.generateDeterministicId(
        docId: 'hash_doc_alpha',
        blockId: 'block_001',
        cognitiveType: 'definition',
      );

      final id2 = SchemaSerializer.generateDeterministicId(
        docId: 'hash_doc_alpha',
        blockId: 'block_001',
        cognitiveType: 'definition',
      );

      final idDifferentType = SchemaSerializer.generateDeterministicId(
        docId: 'hash_doc_alpha',
        blockId: 'block_001',
        cognitiveType: 'mechanism',
      );

      final idDifferentBlock = SchemaSerializer.generateDeterministicId(
        docId: 'hash_doc_alpha',
        blockId: 'block_002',
        cognitiveType: 'definition',
      );

      // Same inputs must yield identical deterministic ID
      expect(id1, equals(id2));
      expect(id1.length, equals(36)); // Standard 8-4-4-4-12 UUID format

      // Changing block or cognitive type must change ID
      expect(id1, isNot(equals(idDifferentType)));
      expect(id1, isNot(equals(idDifferentBlock)));
    });

    test('source_topic is grounded in hierarchical section path rather than duplicating front', () {
      const candidate = PedagogicalCandidateCard(
        front: 'What does setState accomplish in Flutter?',
        back: 'Calling setState signals the framework that internal state has changed, scheduling a rebuild.',
        type: CognitiveQuestionType.mechanism,
        sourceTopic: 'What does setState accomplish in Flutter?', // legacy front duplication
        source: CardSource(
          docId: 'flutter_notes',
          page: 2,
          sectionPath: ['Widget Lifecycle', 'StatefulWidget', 'Reactivity'],
          blockId: 'block_setState',
        ),
      );

      final deck = serializer.serializeDeck(
        deckId: 'deck_flutter',
        deckTitle: 'Flutter Architecture',
        subject: 'Computer Science',
        category: 'Mobile Dev',
        candidateCards: [candidate],
      );

      expect(deck.cards.length, equals(1));
      final card = deck.cards.first;

      // Assert sourceTopic is grounded in the hierarchical section path
      expect(card.sourceTopic, equals('Widget Lifecycle > StatefulWidget > Reactivity'));
      expect(card.sourceTopic, isNot(equals(card.front)));

      // Assert deterministic ID derived from source docId + blockId
      final expectedId = SchemaSerializer.generateDeterministicId(
        docId: 'flutter_notes',
        blockId: 'block_setState',
        cognitiveType: 'mechanism',
      );
      expect(card.id, equals(expectedId));
    });

    test('PedagogicalDeck and PedagogicalCard roundtrip JSON serialization maintains 100% schema compliance', () {
      final card = PedagogicalCard(
        id: '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d',
        deckId: 'deck_101',
        front: 'What is an event loop?',
        back: 'An event loop continually processes tasks and microtasks from queues in single-threaded runtimes.',
        sourceTopic: 'Concurrency > Event Loops',
        cognitiveType: 'definition',
        createdAt: fixedClockTime,
        source: const CardSource(
          docId: 'concurrency_guide',
          page: 5,
          sectionPath: ['Concurrency', 'Event Loops'],
          blockId: 'para_loop',
        ),
        assets: const [
          CardAsset(
            id: 'asset_event_diag',
            type: CardAssetType.diagram,
            content: 'loop: microtask -> event -> render',
            label: 'Event Loop Flow',
          ),
        ],
        confidenceScore: 0.98,
        stability: 2.5,
        difficulty: 3.1,
        elapsedDays: 1,
        scheduledDays: 3,
        lapses: 1,
        fsrsState: 1,
      );

      final deck = PedagogicalDeck(
        schemaVersion: '1.0.0',
        deckId: 'deck_101',
        deckTitle: 'Modern Concurrency',
        subject: 'Computer Science',
        category: 'Study',
        totalCards: 1,
        cards: [card],
        generatedAt: fixedClockTime,
      );

      final json = deck.toJson();
      final roundTripDeck = PedagogicalDeck.fromJson(json);

      expect(roundTripDeck.deckId, equals('deck_101'));
      expect(roundTripDeck.schemaVersion, equals('1.0.0'));
      expect(roundTripDeck.totalCards, equals(1));
      expect(roundTripDeck.generatedAt, equals(fixedClockTime));

      final restoredCard = roundTripDeck.cards.first;
      expect(restoredCard.id, equals(card.id));
      expect(restoredCard.front, equals(card.front));
      expect(restoredCard.back, equals(card.back));
      expect(restoredCard.sourceTopic, equals('Concurrency > Event Loops'));
      expect(restoredCard.source?.docId, equals('concurrency_guide'));
      expect(restoredCard.source?.sectionPath, equals(['Concurrency', 'Event Loops']));
      expect(restoredCard.assets.length, equals(1));
      expect(restoredCard.assets.first.type, equals(CardAssetType.diagram));
      expect(restoredCard.stability, equals(2.5));
      expect(restoredCard.difficulty, equals(3.1));
      expect(restoredCard.lapses, equals(1));
      expect(restoredCard.fsrsState, equals(1));
    });
  });
}
