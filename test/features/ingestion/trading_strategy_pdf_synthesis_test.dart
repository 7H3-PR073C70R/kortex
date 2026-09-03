// ignore_for_file: avoid_print // Diagnostic ignored for local test inspection.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';

void main() {
  test('Trading Strategy PDF synthesis produces high-yield cards with no echo loops', () {
    const pdfPath =
        '/Users/protector/.gemini/antigravity-ide/brain/86b52175-796d-43f5-9254-e878f0a8599e/.user_uploaded/media_1788476266730.pdf';
    final file = File(pdfPath);
    expect(file.existsSync(), isTrue);

    final bytes = file.readAsBytesSync();
    const parser = DocumentParserService();

    final text = parser.extractTextFromBytes(
      bytes,
      fileType: 'pdf',
      filename: "The Only 1 Minute Trading Strategy You'll Ever Need.pdf",
    );

    expect(text.isNotEmpty, isTrue);

    final snippets = parser.synthesizeSnippetsFromDocument(
      documentId: 'test_trading_doc',
      fullText: text,
      filename: "The Only 1 Minute Trading Strategy You'll Ever Need.pdf",
    );

    print('\n==================== LOCAL SYNTHESIZED CARDS (${snippets.length}) ====================');
    for (var i = 0; i < snippets.length; i++) {
      print('\nCARD #${i + 1}');
      print('QUESTION: ${snippets[i].topic}');
      print('ANSWER:   ${snippets[i].rawText}');
      if (snippets[i].latexContent != null) {
        print('LATEX:    ${snippets[i].latexContent}');
      }
    }
    print('=================================================================\n');

    // Assertions:
    // 1. Must produce a healthy number of high-yield cards (at least 8)
    expect(snippets.length, greaterThanOrEqualTo(8));

    // 2. Zero echo loops (Question and Answer must not be the same)
    for (final snippet in snippets) {
      final qNorm = snippet.topic.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
      final aNorm = snippet.rawText.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
      expect(qNorm == aNorm, isFalse, reason: 'Card echoed question: ${snippet.topic}');

      // Must have substantive answers
      expect(snippet.rawText.length, greaterThanOrEqualTo(15));
      expect(snippet.rawText.split(' ').length, greaterThanOrEqualTo(3));
    }

    // 3. Must cover key strategy concepts
    final allQuestions = snippets.map((s) => s.topic.toLowerCase()).join(' ');
    expect(allQuestions.contains('rectangle') || allQuestions.contains('timeframe') || allQuestions.contains('indicator'), isTrue);
  });
}
