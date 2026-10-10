// ignore_for_file: avoid_print, document_ignores

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

String _norm(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

void main() {
  const builder = OfflineCardBuilder();
  const pdfService = LocalPdfParserService();
  const docService = DocumentParserService();

  group('OfflineCardBuilder & Production Pipeline', () {
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

      print('\n[biology_cell_respiration.md] Produced ${cards.length} cards:');
      for (final c in cards.take(5)) {
          print('  • [${c.type.name}] ${c.front} -> ${c.back.replaceAll('\n', ' ')}');
      }

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

    test('sanitizer does not glue capitals (Vitamin C is -> Vitamin Cis) or strip domains', () {
      const sample = '''
Vitamin C is an essential ascorbic acid nutrient.
Plan B or alternative contingency procedures must be followed.
The company is highly profitable. Net revenue exceeded expectations.
For assistance visit https://example.com/help today.
''';
      final sanitized = LocalPdfParserService.sanitizeExtractedText(sample);

      print('\n[Sanitizer Non-Destruction Check]:\n$sanitized');

      expect(sanitized, contains('Vitamin C is'));
      expect(sanitized, isNot(contains('Vitamin Cis')));
      expect(sanitized, contains('Plan B or'));
      expect(sanitized, isNot(contains('Plan Bor')));
      expect(sanitized, contains('profitable. Net'));
      expect(sanitized, contains('https://example.com/help'));
    });

    test('preserves bullet lists as distinct items without collapsing into a single line', () {
      const sample = '''
## Architecture Guidelines
- Build reusable and maintainable widgets
- Write unit tests and perform debugging
- Maintain clear and up-to-date documentation
''';
      final cards = builder.buildCards(sample);
      final listCard = cards.firstWhere((c) => c.type == OfflineCardType.list);

      print('\n[List Card Output]:\nFront: ${listCard.front}\nBack:\n${listCard.back}');

      final bulletLines = listCard.back.split('\n');
      expect(bulletLines.length, greaterThanOrEqualTo(3));
      for (final line in bulletLines) {
        expect(line, startsWith('• '));
      }
    });

    test('isMeaningfulEducationalText supports Unicode and international characters', () {
      expect(
        DocumentParserService.isMeaningfulEducationalText(
          'Àwọn èrò pàtàkì nínú ẹ̀kọ́ náà wúlò púpọ̀ fún àwọn akẹ́kọ̀ọ́.',
        ),
        isTrue,
      );
      expect(
        DocumentParserService.isMeaningfulEducationalText(
          'La photosynthèse est un processus biologique fondamental.',
        ),
        isTrue,
      );
    });

    test('production PDF pipeline: every card back appears in source without corruption', () {
      final dir = Directory('test/fixtures/ingestion');
      for (final file in dir.listSync().whereType<File>()) {
        final name = file.uri.pathSegments.last;
        if (!name.endsWith('.md') && !name.endsWith('.pdf')) continue;
        if (name.contains('corrupt') || name.contains('encrypted') || name.contains('invoice')) continue;

        final bytes = file.readAsBytesSync();
        // Production pipeline: PDFs go through LocalPdfParserService!
        final source = name.endsWith('.pdf')
            ? pdfService.extractTextFromPdfBytes(bytes, filename: name)
            : docService.extractTextFromBytes(
                bytes,
                fileType: name.split('.').last,
                filename: name,
              );

        final normSource = _norm(source);
        final cards = builder.buildCards(source);

          print('\n===== [$name] ${cards.length} cards extracted via production pipeline =====');
        for (final c in cards.take(3)) {
              print('  [${c.type.name}] Q: ${c.front} | A: ${c.back.split('\n').first}');
        }

        expect(cards, isNotEmpty, reason: '[$name] should produce cards');

        for (final c in cards) {
          final back = c.type == OfflineCardType.cloze
              ? c.back.split('\n\n').last
              : c.back;

          // Invariant: no detached-initial capital glue artifacts
          expect(back, isNot(matches(r'\b[A-Z][a-z]{1,15}(?:Cis|Bor|Bvirus)\b')));

          // Invariant: each non-empty line of the back appears in normalized source
          for (final line in back.split('\n')) {
            if (line.trim().isEmpty) continue;
            expect(
              normSource.contains(_norm(line)),
              isTrue,
              reason: '[$name] line not found in source: "$line"',
            );
          }
        }
      }
    });
  });
}
