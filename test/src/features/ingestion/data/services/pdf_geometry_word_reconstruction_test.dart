import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/html_entity_decoder.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('LocalPdfParserService.reconstructLineText and PdfLineLayout.fromTextLine', () {
    test('separates fused words in flutterengineering-book.pdf body text', () {
      final file = File('test/fixtures/ingestion/flutterengineering-book.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      // Page 30 (0-indexed: 29) contains:
      // "of the FloatingActionButton widgetusedforactionbuttons.Modiﬁcationsto"
      final page30Lines = extractor.extractTextLines(startPageIndex: 29);
      final rawTargetLine30 = page30Lines.firstWhere(
        (l) => l.text.contains('FloatingActionButton'),
      );
      final reconstructed30 = LocalPdfParserService.reconstructLineText(rawTargetLine30);
      final layout30 = PdfLineLayout.fromTextLine(rawTargetLine30);

      expect(reconstructed30, contains('widget used for action buttons. Modiﬁcations to'));
      expect(layout30.text, contains('widget used for action buttons. Modiﬁcations to'));

      // Page 31 (0-indexed: 30) contains:
      // "softwareapplicationintodistinctsections,eachaddressingaspeciﬁcaspector"
      final page31Lines = extractor.extractTextLines(startPageIndex: 30);
      final rawTargetLine31 = page31Lines.firstWhere(
        (l) => l.text.contains('sections'),
      );
      final reconstructed31 = LocalPdfParserService.reconstructLineText(rawTargetLine31);
      final layout31 = PdfLineLayout.fromTextLine(rawTargetLine31);

      expect(reconstructed31, contains('software application into distinct sections, each addressing a'));
      expect(layout31.text, contains('software application into distinct sections, each addressing a'));

      doc.dispose();
    });

    test('reconstructs table of contents entries in flutterengineering-book.pdf', () {
      final file = File('test/fixtures/ingestion/flutterengineering-book.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      // Pages 3-5 contain the TOC with displaced spacing
      final page3Lines = extractor.extractTextLines(startPageIndex: 2);
      final tocLine = page3Lines.firstWhere(
        (l) => l.text.contains('PositioninTechEvolution'),
      );
      final rec = LocalPdfParserService.reconstructLineText(tocLine);

      expect(rec, contains('1.5 Flutter’s Position in Tech Evolution'));

      final tocKeyLine = page3Lines.firstWhere(
        (l) => l.text.contains('UsageofKeysinFlutter'),
      );
      final recKey = LocalPdfParserService.reconstructLineText(tocKeyLine);
      expect(recKey, contains('2.8 Signiﬁcance and Usage of Keys in Flutter'));

      doc.dispose();
    });

    test('preserves intra-word kerning and heals broken kerning splits in Flutter_Developer_Case.pdf', () {
      final file = File('test/fixtures/ingestion/Flutter_Developer_Case.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      final page1Lines = extractor.extractTextLines(startPageIndex: 0);
      TextLine? target;
      for (final l in page1Lines) {
        if (l.text.contains('ake-Home') || l.text.contains('Flut')) {
          target = l;
          break;
        }
      }

      expect(target, isNotNull);
      final rec = LocalPdfParserService.reconstructLineText(target!);
      // Ensure the reconstructed text does not contain split words like 'T ake' or 'Flut ter'
      expect(rec, isNot(contains('T ake')));
      expect(rec, isNot(contains('Flut ter')));

      doc.dispose();
    });

    test('does not corrupt RTL text in doc_arabic_machine_learning.pdf', () {
      final file = File('test/fixtures/ingestion/doc_arabic_machine_learning.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      for (var p = 0; p < doc.pages.count; p++) {
        final lines = extractor.extractTextLines(startPageIndex: p);
        for (final line in lines) {
          final rec = LocalPdfParserService.reconstructLineText(line);
          final layout = PdfLineLayout.fromTextLine(line);
          // RTL lines should not have artificial spaces inserted within Arabic words
          expect(rec, equals(line.text));
          expect(layout.text, equals(HtmlEntityDecoder.decode(LocalPdfParserService.repairHeadingQuoteArtifact(line.text))));
        }
      }

      doc.dispose();
    });

    test('preserves normal English spacing in kotlin-reference.pdf without regression', () {
      final file = File('test/fixtures/ingestion/kotlin-reference.pdf');
      if (!file.existsSync()) return;

      final doc = PdfDocument(inputBytes: file.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);

      var linesChecked = 0;
      for (var p = 0; p < 10; p++) {
        final lines = extractor.extractTextLines(startPageIndex: p);
        for (final line in lines) {
          linesChecked++;
          final rec = LocalPdfParserService.reconstructLineText(line);
          // Raw words count must match reconstructed words count
          final rawWords = line.text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
          final recWords = rec.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
          expect(recWords.length, equals(rawWords.length),
              reason: 'Spacing should remain stable for normally spaced docs');
        }
      }

      expect(linesChecked, greaterThan(50));
      doc.dispose();
    });
  });
}
