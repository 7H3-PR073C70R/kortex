import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';

void main() {
  const service = DocumentParserService();

  group('DocumentParserService', () {
    test('extracts text from plain text and markdown bytes', () {
      const text = '''
Part 1: The Basics – Timeframes, Pairs, and Indicators
1.1 The Rectangle Defined
The entire trading plan and strategy are dependent on one thing: the rectangle.
- Entry: We will have an entry inside the rectangle.
- Confirmation: The rectangle provides the necessary confirmation.
- Stop Loss: The SL is placed above or below the rectangle.
- Take Profit: Target 3:1 RR minimum.

1.2 Timeframes
The strategy utilizes the 15-minute (M15) chart and the 1-minute (M1) chart.
''';
      final bytes = Uint8List.fromList(text.codeUnits);
      final extracted = service.extractTextFromBytes(
        bytes,
        fileType: 'txt',
        filename: 'strategy.txt',
      );

      expect(extracted, contains('The Rectangle Defined'));
      expect(extracted, contains('Timeframes'));
    });

    test('synthesizes comprehensive flashcard snippets from document text', () {
      const text = '''
Part 1: The Basics – Timeframes, Pairs, and Indicators
1.1 The Rectangle Defined
The entire trading plan and strategy are dependent on one thing: the rectangle.
- Entry: We will have an entry inside the rectangle.
- Stop Loss: Placed above or below rectangle.
- Take Profit: Target 3:1 RR minimum.

1.2 Timeframes
M15 Chart identifies high probability setup. M1 Chart executes precise entry.

1.4 Indicators: Identifying Direction
If price is above 50/200 EMA, look for longs.
If price is below EMA, look for shorts.

2.2 Strength vs. Weakness: The Trigger
Weakness is when price sweeps a low/high and fails to close beyond,
creating a rejection wick.

Step 3: Draw the Rectangle and Enter on the M1 Flip
Draw rectangle from M15 close to extreme.
Enter on M1 candle close outside rectangle.
''';

      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_trading_101',
        fullText: text,
        filename: 'trading_strategy.pdf',
      );

      expect(snippets.length, greaterThanOrEqualTo(5));
      expect(
        snippets.any((s) => s.topic.toLowerCase().contains('rectangle')),
        isTrue,
      );
      expect(
        snippets.any((s) => s.topic.toLowerCase().contains('timeframe')),
        isTrue,
      );
      expect(
        snippets.any(
          (s) =>
              s.topic.toLowerCase().contains('direction') ||
              s.topic.toLowerCase().contains('ema') ||
              s.topic.toLowerCase().contains('indicators'),
        ),
        isTrue,
      );
      expect(
        snippets.any(
          (s) =>
              s.topic.toLowerCase().contains('weakness') ||
              s.topic.toLowerCase().contains('sweep') ||
              s.topic.toLowerCase().contains('trigger'),
        ),
        isTrue,
      );
      expect(
        snippets.any(
          (s) =>
              s.topic.toLowerCase().contains('step 3') ||
              s.topic.toLowerCase().contains('rectangle') ||
              s.topic.toLowerCase().contains('flip'),
        ),
        isTrue,
      );

      // Verify formulas are generated
      final emaSnippet = snippets.firstWhere(
        (s) => s.topic.contains('Indicators') || s.rawText.contains('EMA'),
      );
      expect(emaSnippet.latexContent, isNotNull);
      expect(emaSnippet.latexContent, contains('EMA'));
    });

    test('gracefully handles empty text without fabricating dummy cards', () {
      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_empty',
        fullText: '',
        filename: 'trading_strategy.pdf',
      );

      expect(snippets, isEmpty);
    });

    test('extracts embedded JPEG and PNG images from binary PDF stream', () {
      // Create mock PDF bytes with embedded JPEG SOI and EOI
      final mockPdfWithImage = <int>[
        ...utf8.encode(
          '%PDF-1.4\n1 0 obj\n<< /Type /XObject /Subtype /Image >>\nstream\n',
        ),
        0xFF, 0xD8, 0xFF, 0xE0, // JPEG SOI + APP0
        ...List.filled(100, 0x42), // Image payload
        0xFF, 0xD9, // JPEG EOI
        ...utf8.encode('\nendstream\nendobj\n%%EOF'),
      ];

      final extractedImages = service.extractImagesFromPdfBytes(
        Uint8List.fromList(mockPdfWithImage),
      );

      expect(extractedImages.isNotEmpty, isTrue);
      expect(extractedImages.first.extension, 'jpg');
      expect(extractedImages.first.bytes.length, greaterThan(100));
    });

    test('associates visual diagram URLs with generated flashcards', () {
      const notes = '''
Mitosis: The process where a single cell divides into two identical daughter cells.
Meiosis: A type of cell division that reduces the number of chromosomes in the parent cell by half.
Photosynthesis is the biochemical process that converts sunlight into chemical energy stored in glucose.
''';

      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_visual',
        fullText: notes,
        filename: 'biology.pdf',
        imageUrls: [
          'https://api.kortex.app/storage/v1/object/public/card-assets/mitosis.jpg',
          'https://api.kortex.app/storage/v1/object/public/card-assets/meiosis.jpg',
          'https://api.kortex.app/storage/v1/object/public/card-assets/photosynthesis.jpg',
        ],
      );

      final visualCards = snippets.where((s) => s.imageUrl != null).toList();
      expect(visualCards.length, 3);
      expect(visualCards.first.imageUrl, contains('mitosis.jpg'));
    });

    test('deterministically parses Term: Definition and Q&A pairs', () {
      const notes = '''
Mitosis: The process where a single cell divides into two identical daughter cells.
Meiosis: A type of cell division that reduces the number of chromosomes in the parent cell by half.
Q: What is the primary function of ATP in cells? A: It acts as the universal energy currency for cellular reactions.
''';

      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_bio_101',
        fullText: notes,
        filename: 'biology_notes.txt',
      );

      expect(snippets.length, 3);
      expect(snippets[0].topic, 'What is Mitosis?');
      expect(snippets[0].rawText, contains('daughter cells'));
      expect(snippets[1].topic, 'What is Meiosis?');
      expect(snippets[1].rawText, contains('reduces the number'));
      expect(snippets[2].topic, contains('primary function of ATP'));
      expect(snippets[2].rawText, contains('energy currency'));
    });

    test(
      'robustly parses narrative text without explicit structural markers',
      () {
        const narrativeProse = '''
Photosynthesis is the biochemical process that converts light energy into chemical energy stored in glucose.
Cellular respiration occurs in the mitochondria where ATP is produced for cellular work.
Newton's second law states that force equals mass multiplied by acceleration in classical mechanics.
''';

        final snippets = service.synthesizeSnippetsFromDocument(
          documentId: 'doc_narrative_101',
          fullText: narrativeProse,
          filename: 'narrative_essay.txt',
        );

        expect(snippets.length, greaterThanOrEqualTo(3));
        expect(
          snippets.any((s) => s.topic.contains('Photosynthesis')),
          isTrue,
        );
        expect(
          snippets.any((s) => s.topic.contains('Cellular respiration')),
          isTrue,
        );
        expect(
          snippets.any((s) => s.topic.contains("Newton's second law")),
          isTrue,
        );
      },
    );
  });
}
