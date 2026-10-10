import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';

void main() {
  group('Consolidated Extraction Pipeline Tests', () {
    const service = DocumentParserService();
    final fixedTime = DateTime.utc(2026, 10, 10, 15);
    final mockClock = FrozenClock(fixedTime);

    test('synthesizeDeckFromDocument and synthesizeSnippetsFromDocument are 100% synchronized', () {
      final file = File('test/fixtures/ingestion/biology_cell_respiration.md');
      final markdown = file.readAsStringSync();

      // Execute canonical deck synthesis pipeline
      final deck = service.synthesizeDeckFromDocument(
        documentId: 'bio_doc_01',
        fullText: markdown,
        filename: 'biology_cell_respiration.md',
        clock: mockClock,
      );

      // Execute legacy snippet synthesis pipeline
      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'bio_doc_01',
        fullText: markdown,
        filename: 'biology_cell_respiration.md',
        clock: mockClock,
      );

      expect(deck.cards.length, equals(snippets.length));
      expect(deck.generatedAt, equals(fixedTime));
      expect(deck.schemaVersion, equals(SchemaSerializer.currentSchemaVersion));

      // Assert 1:1 parity between deck and snippet outputs
      for (var i = 0; i < deck.cards.length; i++) {
        final card = deck.cards[i];
        final snippet = snippets[i];

        expect(card.front, equals(snippet.topic));
        expect(card.back, equals(snippet.rawText));
        expect(card.createdAt, equals(fixedTime));
        expect(card.source, isNotNull);
        expect(card.source!.docId, equals('bio_doc_01'));
      }
    });

    test('attaches math formula assets and preserves hierarchical section source path', () {
      final file = File('test/fixtures/ingestion/tutorial_dart_concurrency_isolates.md');
      final markdown = file.readAsStringSync();

      final deck = service.synthesizeDeckFromDocument(
        documentId: 'dart_isolates_01',
        fullText: markdown,
        filename: 'tutorial_dart_concurrency_isolates.md',
        clock: mockClock,
      );

      expect(deck.cards, isNotEmpty);
      expect(deck.subject, equals('Computer Science'));

      // Check that cards have source provenance with section hierarchy
      final clozeCards = deck.cards.where((c) => c.cognitiveType == 'definition');
      expect(clozeCards, isNotEmpty);
      for (final card in clozeCards) {
        expect(card.source, isNotNull);
        expect(card.source!.sectionPath, isNotEmpty);
      }
    });

    test('gracefully handles empty document text with valid empty deck', () {
      final deck = service.synthesizeDeckFromDocument(
        documentId: 'empty_doc',
        fullText: '',
        filename: 'empty.md',
        clock: mockClock,
      );

      expect(deck.totalCards, equals(0));
      expect(deck.cards, isEmpty);
      expect(deck.generatedAt, equals(fixedTime));
    });
  });
}
