import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('repairHeadingQuoteArtifact unit tests', () {
    test('repairs Kotlin heading samples', () {
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Hello’ world'), 'Hello world');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Get’ started’ with’ Kotlin'), 'Get started with Kotlin');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Choose’ your’ Kotlin’ use’ case'), 'Choose your Kotlin use case');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Welcome’ to’ our’ tour’ of’ Kotlin!'), 'Welcome to our tour of Kotlin!');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('String’ templates'), 'String templates');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Next’ step'), 'Next step');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Kotlin’ Docs'), 'Kotlin Docs');
    });

    test('preserves genuine contractions and possessives', () {
      expect(LocalPdfParserService.repairHeadingQuoteArtifact("Support’ for’ calling’ Java's’ code"), "Support for calling Java's code");
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Don’t do this in Kotlin'), 'Don’t do this in Kotlin');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('The user’s input'), 'The user’s input');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('It’s a valid feature'), 'It’s a valid feature');
    });

    test('repairs quotes glued between lowercase words', () {
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Intermediate’flow’operators'), 'Intermediate flow operators');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Is’anything’missing?'), 'Is anything missing?');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact("What's’next?"), "What's next?");
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Welcome’to’our’tour’of Kotlin!'), 'Welcome to our tour of Kotlin!');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Kotlin’s’standard’library'), 'Kotlin’s standard library');
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Expand Library authors’ guidelines'), 'Expand Library authors’ guidelines');
      expect(
        LocalPdfParserService.repairHeadingQuoteArtifact('There’s a whole pizza so you won’t get a boost'),
        'There’s a whole pizza so you won’t get a boost',
      );
    });

    test('repairs unspaced uppercase transitions', () {
      expect(LocalPdfParserService.repairHeadingQuoteArtifact('Hello’World'), 'Hello World');
    });

    test('eliminates heading quote artifact on target pages 65-85 of kotlin-reference.pdf', () async {
      final file = File('test/fixtures/ingestion/kotlin-reference.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      var artifactCount = 0;
      var headingsChecked = 0;

      for (var i = 65; i < 85; i++) {
        final textLines = extractor.extractTextLines(startPageIndex: i);
        for (final line in textLines) {
          final rawText = line.text.trim();
          if (line.fontSize >= 20.0 || line.fontName.contains('Helvetica')) {
            final cleaned = LocalPdfParserService.repairHeadingQuoteArtifact(rawText);
            headingsChecked++;
            if (RegExp(r'(?<=\w)[’\u2019](?=\s|$)').hasMatch(cleaned)) {
              artifactCount++;
            }
          }
        }
      }
      doc.dispose();

      expect(artifactCount, equals(0), reason: 'Zero heading quote artifacts should remain');
      expect(headingsChecked, greaterThan(10));
    });

    test('cards built from repaired Kotlin text have 0 heading quote artifacts in topics and stems', () async {
      final file = File('test/fixtures/ingestion/kotlin-reference.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      final pageTexts = <String>[];
      for (var i = 68; i < 75; i++) {
        final textLines = extractor.extractTextLines(startPageIndex: i);
        final lines = textLines.map(PdfLineLayout.fromTextLine).toList();
        final pageText = lines.map((l) => l.text).join('\n');
        pageTexts.add(pageText);
      }
      doc.dispose();

      const builder = OfflineCardBuilder();
      final markdown = pageTexts.join('\n\n');
      final cards = builder.buildCards(markdown);

      var artifactInCards = 0;
      for (final card in cards) {
        if (RegExp(r'(?<=\w)[’\u2019](?=\s|$)').hasMatch(card.heading ?? '')) {
          artifactInCards++;
        }
        if (RegExp(r'(?<=\w)[’\u2019](?=\s|$)').hasMatch(card.front)) {
          artifactInCards++;
        }
      }

      expect(artifactInCards, equals(0));
    });
  });
}
