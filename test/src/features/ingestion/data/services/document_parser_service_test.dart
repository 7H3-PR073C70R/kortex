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
        snippets.any((s) => s.topic.contains('Rectangle Defined')),
        isTrue,
      );
      expect(
        snippets.any((s) => s.topic.contains('Timeframes')),
        isTrue,
      );
      expect(
        snippets.any(
          (s) =>
              s.topic.contains('Indicators') || s.topic.contains('Direction'),
        ),
        isTrue,
      );
      expect(
        snippets.any(
          (s) =>
              s.topic.contains('Strength vs. Weakness') ||
              s.topic.contains('Trigger'),
        ),
        isTrue,
      );
      expect(
        snippets.any(
          (s) => s.topic.contains('Step 3') || s.topic.contains('Rectangle'),
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

    test('generates complete high-yield fallback if text is sparse', () {
      final snippets = service.synthesizeSnippetsFromDocument(
        documentId: 'doc_empty',
        fullText: '',
        filename: 'trading_strategy.pdf',
      );

      expect(snippets.length, 10);
      expect(snippets.first.topic, '1.1 The Rectangle Defined');
      expect(snippets.last.topic, 'Pre-Trade Confirmation Checklist');
    });
  });
}
