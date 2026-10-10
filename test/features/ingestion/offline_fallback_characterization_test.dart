// ignore_for_file: avoid_print, document_ignores

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/schema_serializer.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

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
      final bytes = file.readAsBytesSync();

      if (name.contains('encrypted')) {
        expect(
          () => service.extractTextFromBytes(bytes, fileType: ext, filename: name),
          throwsA(isA<EncryptedPdfException>()),
        );
        return;
      }

      if (name.contains('corrupt')) {
        expect(
          () => service.extractTextFromBytes(bytes, fileType: ext, filename: name),
          throwsA(isA<CorruptDocumentException>()),
        );
        return;
      }

      final text = service.extractTextFromBytes(
        bytes,
        fileType: ext,
        filename: name,
      );
      if (name.contains('Flutter_Dev')) {
        print('=== RAW TEXT OF $name ===\n$text\n=== END RAW TEXT ===');
      }
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

      final outputDir = Directory('build/characterization_output')
        ..createSync(recursive: true);
      final jsonFile = File('${outputDir.path}/${cleanName}_deck.json')
      ..writeAsStringSync(deck.toPrettyJson());

      print('\n===== $name: ${deck.totalCards} cards (PedagogicalDeckSchema) =====');
      print('Output saved to: ${jsonFile.path}\n');

      expect(cards, isNotNull);
      if (!name.contains('invoice')) {
        expect(deck.cards, isNotEmpty);
      }
      expect(deck.schemaVersion, equals('1.0.0'));
      expect(jsonFile.existsSync(), isTrue);
    });
  }
}
