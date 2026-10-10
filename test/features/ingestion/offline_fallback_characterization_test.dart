// ignore_for_file: avoid_print, document_ignores

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';

/// Characterization harness for the offline (no-server) card synthesis.
///
/// It outputs the real JSON solution conforming to PedagogicalDeckSchema
/// ready to be synced directly to the database.
void main() {
  const service = DocumentParserService();
  const serializer = SchemaSerializer();
  final dir = Directory('test/fixtures/ingestion');

  final textFixtures = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md') || f.path.endsWith('.pdf'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in textFixtures) {
    final name = file.uri.pathSegments.last;
    test('dump offline cards: $name', () {
      final ext = name.split('.').last;
      final text = service.extractTextFromBytes(
        file.readAsBytesSync(),
        fileType: ext,
        filename: name,
      );
      final cards = service.synthesizeSnippetsFromDocument(
        documentId: 'fixture',
        fullText: text,
        filename: name,
      );

      final cleanName = name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final deck = serializer.fromExtractionModels(
        deckId: 'deck_${name.replaceAll(RegExp('[^a-zA-Z0-9]'), '_')}',
        deckTitle: cleanName,
        subject: name.toLowerCase().contains('bio')
            ? 'Biology'
            : (name.toLowerCase().contains('flutter')
                ? 'Flutter'
                : 'Computer Science'),
        category: 'Study',
        models: cards,
      );

      print('\n===== $name: ${deck.totalCards} cards (PedagogicalDeckSchema) =====\n');
      print(deck.toPrettyJson());

      expect(cards, isNotNull);
      expect(deck.cards, isNotEmpty);
      expect(deck.schemaVersion, equals('1.0.0'));
    });
  }
}
