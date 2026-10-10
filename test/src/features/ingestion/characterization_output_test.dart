import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/entities/pedagogical_card_schema.dart';

void main() {
  const docService = DocumentParserService();
  const pdfService = LocalPdfParserService();
  final frozenClock = FrozenClock(DateTime.utc(2026, 10, 10, 12));

  final outputDir = Directory('build/characterization_output');

  setUpAll(() {
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
  });

  group('Supabase Ingestion Characterization Output Suite', () {
    test(
      'processes benchmark fixtures and generates exact Supabase payloads into build/characterization_output',
      () {
        final fixturesDir = Directory('test/fixtures/ingestion');
        expect(
          fixturesDir.existsSync(),
          isTrue,
          reason: 'Fixtures directory must exist',
        );

        final files = (fixturesDir.listSync().whereType<File>().where((f) {
          final name = f.uri.pathSegments.last;
          return !name.endsWith('.json') &&
              !name.endsWith('.png') &&
              !name.endsWith('.jpg') &&
              !name.contains('corrupt') &&
              !name.contains('encrypted');
        }).toList())..sort((a, b) => a.path.compareTo(b.path));

        expect(
          files,
          isNotEmpty,
          reason: 'Must have valid benchmark fixtures to process',
        );

        const encoder = JsonEncoder.withIndent('  ');
        final manifestSummaries = <Map<String, dynamic>>[];
        var totalCardsGenerated = 0;

        for (final file in files) {
          final filename = file.uri.pathSegments.last;
          final baseName = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
          final ext = filename.split('.').last.toLowerCase();
          final effectiveExt = ext == 'text' ? 'txt' : ext;
          final bytes = file.readAsBytesSync();

          // 1. Extract raw text with audit reporting
          final report = ExtractionReport(
            filename: filename,
            fileType: effectiveExt,
          );
          String fullText;
          try {
            fullText = effectiveExt == 'pdf'
                ? pdfService.extractTextFromPdfBytes(
                    bytes,
                    filename: filename,
                    report: report,
                  )
                : docService.extractTextFromBytes(
                    bytes,
                    fileType: effectiveExt,
                    filename: filename,
                    report: report,
                  );
          } on Object {
            // If a file fails parsing or is malformed, skip payload generation
            continue;
          }

          if (fullText.trim().isEmpty) continue;

          final documentId = 'doc_${filename.hashCode.abs()}';

          // 2. Synthesize Pedagogical Deck
          final pedagogicalDeck = docService.synthesizeDeckFromDocument(
            documentId: documentId,
            fullText: fullText,
            filename: filename,
            report: report,
            clock: frozenClock,
          );

          if (pedagogicalDeck.cards.isEmpty) continue;

          final deckUuid = UuidUtils.generate();
          const testUserId = 'usr_characterization_test_001';

          // 3. Exact Supabase 'decks' table payload (matching DecksRemoteDataSourceImpl)
          final supabaseDeckRecord = <String, dynamic>{
            'id': deckUuid,
            'title': pedagogicalDeck.deckTitle,
            'subject': pedagogicalDeck.subject,
            'total_cards': pedagogicalDeck.totalCards,
            'due_cards': pedagogicalDeck.totalCards,
            'mastery_rate': 0.0,
            'description':
                'Auto-synthesized from document $documentId ($filename)',
            'user_id': testUserId,
            'course_id': null,
            'course_code': null,
          };

          // 4. Exact Supabase 'flashcards' table bulk insert payload (matching DecksRemoteDataSourceImpl)
          final supabaseCardsRecords = pedagogicalDeck.cards.map((c) {
            final cardUuid = UuidUtils.generate();
            return <String, dynamic>{
              'id': cardUuid,
              'deck_id': deckUuid,
              'user_id': testUserId,
              'front': c.front,
              'back': c.back,
              'front_latex': null,
              'back_latex': c.backLatex,
              'source_topic': c.sourceTopic,
              'interval': 0,
              'repetitions': 0,
              'ease_factor': 2.5,
              'next_due_date': frozenClock
                  .now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
            };
          }).toList();

          // 5. Build unified output document for verification and offline replay
          final outputPayload = <String, dynamic>{
            'metadata': {
              'document_filename': filename,
              'document_id': documentId,
              'file_type': effectiveExt,
              'bytes_length': bytes.length,
              'generated_at': frozenClock.now().toIso8601String(),
              'total_cards': pedagogicalDeck.totalCards,
            },
            'supabase_deck_payload': supabaseDeckRecord,
            'supabase_cards_payload': supabaseCardsRecords,
            'pedagogical_deck_schema': pedagogicalDeck.toJson(),
            'extraction_report': {
              'total_lines_retained': report.totalLinesRetained,
              'total_dropped_elements': report.totalDroppedElements,
              'is_scanned': report.isScanned,
              'warnings': report.warnings,
            },
          };

          // 6. Write characterization JSON file
          final outFile = File('${outputDir.path}/$baseName.json')
            ..writeAsStringSync(encoder.convert(outputPayload));

          expect(outFile.existsSync(), isTrue);
          expect(outFile.lengthSync(), greaterThan(0));

          totalCardsGenerated += pedagogicalDeck.totalCards;

          manifestSummaries.add({
            'filename': filename,
            'output_json': '$baseName.json',
            'deck_title': pedagogicalDeck.deckTitle,
            'subject': pedagogicalDeck.subject,
            'card_count': pedagogicalDeck.totalCards,
            'bytes': bytes.length,
          });
        }

        // 7. Write index manifest
        final indexManifest = <String, dynamic>{
          'timestamp': frozenClock.now().toIso8601String(),
          'total_documents_processed': manifestSummaries.length,
          'total_cards_synthesized': totalCardsGenerated,
          'output_directory': outputDir.path,
          'documents': manifestSummaries,
        };

        final indexFile = File('${outputDir.path}/index.json')
          ..writeAsStringSync(encoder.convert(indexManifest));

        expect(indexFile.existsSync(), isTrue);
        expect(manifestSummaries.length, greaterThanOrEqualTo(20));
        expect(totalCardsGenerated, greaterThan(100));

        stdout
          ..writeln(
            '\n============================================================',
          )
          ..writeln(' CHARACTERIZATION OUTPUT SUMMARY')
          ..writeln(
            '============================================================',
          )
          ..writeln(' Output Directory : ${outputDir.path}')
          ..writeln(' Documents Dumped : ${manifestSummaries.length}')
          ..writeln(' Total Cards JSON : $totalCardsGenerated cards')
          ..writeln(' Index Manifest   : ${indexFile.path}')
          ..writeln(
            '============================================================\n',
          );
      },
    );
  });
}
