import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  late LocalPdfParserService service;

  setUp(() {
    service = const LocalPdfParserService();
  });

  Uint8List createSamplePdfBytes(List<String> lines) {
    final document = PdfDocument();
    final page = document.pages.add();
    var y = 10.0;
    for (final line in lines) {
      page.graphics.drawString(
        line,
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: Rect.fromLTWH(10, y, 500, 60),
      );
      y += 70;
    }
    final bytes = Uint8List.fromList(document.saveSync());
    document.dispose();
    return bytes;
  }

  group('LocalPdfParserService Test Suite', () {
    test('extracts text from PDF bytes using Syncfusion PdfTextExtractor', () {
      final bytes = createSamplePdfBytes([
        'Mitochondria is the powerhouse of the cell.',
      ]);
      final text = service.extractTextFromPdfBytes(bytes);
      expect(text, contains('Mitochondria'));
    });

    test(
      'parses PDF bytes into structured flashcards with multi-tiered heuristics',
      () {
        final bytes = createSamplePdfBytes([
          'Q: What is Mitosis? A: Mitosis is the process of cell division producing two genetically identical daughter cells.',
          'Meiosis: Meiosis is a specialized type of cell division that reduces chromosome count by half to produce gametes.',
          'Photosynthesis is the biochemical process that converts sunlight and carbon dioxide into chemical energy stored in glucose.',
        ]);

        final cards = service.parsePdfBytesToFlashcards(
          documentId: 'doc_syncfusion_1',
          bytes: bytes,
          filename: 'biology.pdf',
        );

        expect(cards.length, greaterThanOrEqualTo(3));
        expect(cards.any((c) => c.topic.contains('Mitosis')), isTrue);
        expect(cards.any((c) => c.topic.contains('Meiosis')), isTrue);
        expect(cards.any((c) => c.topic.contains('Photosynthesis')), isTrue);
      },
    );

    test('filters out corrupted binary stream noise from extracted text', () {
      const corruptedNoise = '>÷B[t {jÜ>tÑ\x00\x01\x02\x03\x04\x05\x06\x07';
      expect(
        LocalPdfParserService.isCorruptedBinaryNoise(corruptedNoise),
        isTrue,
      );

      const validEducationalText =
          'Photosynthesis converts sunlight into glucose and oxygen.';
      expect(
        LocalPdfParserService.isCorruptedBinaryNoise(validEducationalText),
        isFalse,
      );

      const mixedText = '''
Photosynthesis converts sunlight into chemical energy.
>÷B[t {jÜ>tÑ\x00\x01\x02\x03\x04\x05\x06\x07\x08
Cellular respiration generates ATP in the mitochondria.
''';
      final clean = LocalPdfParserService.sanitizeExtractedText(mixedText);
      expect(clean, contains('Photosynthesis'));
      expect(clean, contains('Cellular respiration'));
      expect(clean, isNot(contains('>÷B[t')));
    });

    test('filters out PDF renderer metadata and watermark artifacts', () {
      expect(
        LocalPdfParserService.isMetadataOrRendererArtifact(
          'Producer: Skia/PDF m115',
        ),
        isTrue,
      );
      expect(
        LocalPdfParserService.isMetadataOrRendererArtifact(
          'CreationDate: D:20260902',
        ),
        isTrue,
      );
      expect(
        LocalPdfParserService.isMetadataOrRendererArtifact('Page 1 of 15'),
        isTrue,
      );
      expect(
        LocalPdfParserService.isMetadataOrRendererArtifact(
          'Mitosis is the division of somatic cells into two identical cells.',
        ),
        isFalse,
      );
    });

    test(
      'rejects punctuation glyph soup without fabricating dummy placeholder cards',
      () {
        const punctuationGlyphSoup =
            '(-,,-,.+++O..O//.--///O//.../../...--/---////...,,,...-,,...///O//O//.--,++,++O..0..O//,++..--O//.--.--/../..-.,/.././...../..O..,+';

        expect(
          DocumentParserService.isMeaningfulEducationalText(
            punctuationGlyphSoup,
          ),
          isFalse,
        );

        final cards = service.parsePdfBytesToFlashcards(
          documentId: 'doc_glyph_soup',
          bytes: Uint8List.fromList(utf8.encode(punctuationGlyphSoup)),
          filename: 'corrupted.pdf',
        );

        expect(cards, isEmpty);
      },
    );

    test(
      'gracefully handles empty or corrupted PDF bytes returning empty list',
      () {
        final emptyBytes = Uint8List(0);
        final text = service.extractTextFromPdfBytes(emptyBytes);
        expect(text, isEmpty);

        final cards = service.parsePdfBytesToFlashcards(
          documentId: 'doc_empty',
          bytes: emptyBytes,
          filename: 'empty.pdf',
        );
        expect(cards, isEmpty);
      },
    );
  });
}
