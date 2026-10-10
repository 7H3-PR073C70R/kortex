import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

void main() {
  const builder = OfflineCardBuilder();

  group('OfflineCardBuilder', () {
    test('returns no cards for text with nothing usable', () {
      expect(builder.buildCards(''), isEmpty);
      expect(builder.buildCards('12\n\n34\n----'), isEmpty);
    });

    test('builds glossary, definition, list and cloze cards from markdown', () {
      final text = File(
        'test/fixtures/ingestion/biology_cell_respiration.md',
      ).readAsStringSync();
      final cards = builder.buildCards(text);
      final types = cards.map((c) => c.type).toSet();

      expect(
        types,
        containsAll(<OfflineCardType>{
          OfflineCardType.glossary,
          OfflineCardType.definition,
          OfflineCardType.list,
          OfflineCardType.cloze,
        }),
      );
      final atp = cards.firstWhere((c) => c.front == 'What is ATP?');
      expect(atp.back, 'The main energy currency of the cell.');
    });

    test(
      'drops page numbers and does not leak the next heading into answers',
      () {
        final cards = builder.buildCards(
          File(
            'test/fixtures/ingestion/biology_cell_respiration.md',
          ).readAsStringSync(),
        );
        for (final c in cards) {
          expect(c.back, isNot(contains('Page 1 of 2')));
          expect(c.back, isNot(contains('Key Terms')));
        }
      },
    );

    test('never invents text: every back appears in the source', () {
      final dir = Directory('test/fixtures/ingestion');
      const service = DocumentParserService();
      for (final file in dir.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (!name.endsWith('.md') && !name.endsWith('.pdf')) continue;
        final source = service.extractTextFromBytes(
          file.readAsBytesSync(),
          fileType: name.split('.').last,
          filename: name,
        );
        final normSource = _norm(source);
        final cards = builder.buildCards(source);

        for (final c in cards) {
          // Cloze backs are "<term>\n\n<sentence>"; check the sentence part.
          final back = c.type == OfflineCardType.cloze
              ? c.back.split('\n\n').last
              : c.back;
          expect(
            normSource.contains(_norm(back)),
            isTrue,
            reason: '[$name] back not found in source: "${c.back}"',
          );
        }
      }
    });
  });
}
