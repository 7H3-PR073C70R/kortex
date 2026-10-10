import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';

/// Characterization harness for the offline (no-server) card synthesis.
///
/// It dumps the cards produced for each fixture so quality can be reviewed
/// and compared before/after the offline fallback rewrite.
void main() {
  const service = DocumentParserService();
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
      final out = StringBuffer('\n===== $name: ${cards.length} cards =====\n');
      for (final c in cards.take(12)) {
        out
          ..writeln('Q: ${c.topic}')
          ..writeln('A: ${c.rawText}')
          ..writeln('---');
      }
      // ignore: avoid_print
      print(out);
      expect(cards, isNotNull);
    });
  }
}
