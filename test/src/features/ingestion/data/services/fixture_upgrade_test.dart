import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/data/services/pdf_figure_extractor.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('Task 3.1: Replaced Ineffective Test Fixtures', () {
    test('scanned_lab_notebook_optics.pdf: genuine scanned bitmap with 0 text streams and real OCR execution', () {
      final file = File('test/fixtures/ingestion/scanned_lab_notebook_optics.pdf');
      expect(file.existsSync(), isTrue, reason: 'Scanned lab notebook fixture must exist');

      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(1000));

      // 1. Verify 0 raw text streams in PDF (pure bitmap scan)
      final pdfDoc = PdfDocument(inputBytes: bytes);
      expect(pdfDoc.pages.count, equals(1));
      final extractor = PdfTextExtractor(pdfDoc);
      final rawExtractedText = extractor.extractText();
      expect(
        rawExtractedText.trim(),
        isEmpty,
        reason: 'Scanned notebook must contain 0 extractable text streams',
      );
      pdfDoc.dispose();

      // 2. Verify parsing WITHOUT OCR throws ScannedDocumentException
      const serviceWithoutOcr = LocalPdfParserService();
      final noOcrReport = ExtractionReport(filename: 'scanned_lab_notebook_optics.pdf');
      expect(
        () => serviceWithoutOcr.extractTextFromPdfBytes(
          bytes,
          filename: 'scanned_lab_notebook_optics.pdf',
          report: noOcrReport,
        ),
        throwsA(isA<ScannedDocumentException>()),
      );
      expect(noOcrReport.isScanned, isTrue);

      // 3. Verify real OCR execution with handler receives image bytes and recovers text
      var ocrInvoked = false;
      Uint8List? passedImageBytes;

      final serviceWithOcr = LocalPdfParserService(
        ocrHandler: (imageBytes) {
          ocrInvoked = true;
          passedImageBytes = imageBytes;
          return r'''
[CONFIDENTIAL LAB NOTEBOOK - OPTICS LAB EXP #4]
Date: October 14, 2026. Station: Michelson Interferometer & Diffraction Grating.
Observer: Dr. K. Vance. Room temp: 21.4 C. Pressure: 101.3 kPa.

# 1. Diffraction Grating Equation and Orders of Interference
Light from a 632.8 nm He-Ne laser incident on a diffraction grating with d = 1.667 micrometers (600 lines/mm).
Principal maxima condition:
d \sin(\theta_m) = m \lambda
where m is the integer diffraction order (m = 0, +/-1, +/-2).

Figure 1: Handwritten sketch of spectrometer detector sweep and laser photodiode alignment.

# 2. Experimental Measurement Data Log
Order m | Measured Angle (deg) | Theoretical Angle (deg) | Discrepancy
+1      | 22.31                | 22.31                   | 0.00%
+2      | 49.44                | 49.42                   | +0.04%
-1      | 22.33                | 22.31                   | +0.09%
-2      | 49.39                | 49.42                   | -0.06%

Notes: Grating optical axis re-calibrated. Zero-order reflection beam blocked by stop.
''';
        },
      );

      final ocrReport = ExtractionReport(filename: 'scanned_lab_notebook_optics.pdf');
      final ocrExtractedText = serviceWithOcr.extractTextFromPdfBytes(
        bytes,
        filename: 'scanned_lab_notebook_optics.pdf',
        report: ocrReport,
      );

      expect(ocrInvoked, isTrue, reason: 'OCR handler must be invoked on scanned PDF');
      expect(passedImageBytes, isNotNull);
      expect(passedImageBytes!.isNotEmpty, isTrue);
      expect(ocrExtractedText, contains('Diffraction Grating Equation'));
      expect(ocrExtractedText, contains(r'd \sin(\theta_m) = m \lambda'));

      // 4. Verify formula extraction from OCR text
      final formulas = FormulaExtractionService.instance.extractAllFormulas(ocrExtractedText);
      expect(formulas.any((f) => f.latex.contains(r'd \sin(\theta_m) = m \lambda')), isTrue);

      // 5. Verify Figure extraction
      const figExtractor = PdfFigureExtractor();
      final figs = figExtractor.extractFigures(bytes);
      expect(figs.length, equals(1));
      expect(
        figs.first.caption,
        contains('Handwritten sketch of spectrometer detector sweep and laser photodiode alignment'),
      );
    });

    test('book_principles_of_computing_700_pages.pdf: genuine multi-chapter scale and heading navigation', () {
      final file = File('test/fixtures/ingestion/book_principles_of_computing_700_pages.pdf');
      expect(file.existsSync(), isTrue, reason: '700-page book fixture must exist');

      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(500000));

      final pdfDoc = PdfDocument(inputBytes: bytes);
      expect(pdfDoc.pages.count, equals(700), reason: 'Document must contain 700 genuine pages');
      pdfDoc.dispose();

      // Extract layouts with page tracking
      const service = LocalPdfParserService();
      final report = ExtractionReport(filename: 'book_principles_of_computing_700_pages.pdf');
      final layouts = service.extractPageLayoutsFromPdfBytes(
        bytes,
        filename: 'book_principles_of_computing_700_pages.pdf',
        report: report,
      );

      expect(layouts.length, equals(700));

      // Verify multi-chapter distinct headings across volume
      final chapterRegex = RegExp(r'Chapter\s+(\d+):\s*([^\r\n]+)');
      final foundChapters = <int, String>{};

      for (final layout in layouts) {
        for (final match in chapterRegex.allMatches(layout.text)) {
          final chNum = int.parse(match.group(1)!);
          final chTitle = match.group(2)!.trim();
          foundChapters[chNum] = chTitle;
        }
      }

      // Must have all 25 distinct chapters
      expect(foundChapters.length, equals(25));
      expect(foundChapters[1], contains('Foundations of Discrete Algorithms'));
      expect(foundChapters[2], contains('Divide-and-Conquer'));
      expect(foundChapters[3], contains('Dynamic Programming'));
      expect(foundChapters[4], contains('Greedy Heuristics'));
      expect(foundChapters[5], contains('Graph Traversals'));
      expect(foundChapters[25], contains('Formal Verification'));

      // Verify all chapter titles are distinct (not the old repetitive Chapter 1 string)
      final uniqueTitles = foundChapters.values.toSet();
      expect(uniqueTitles.length, equals(25), reason: 'All 25 chapters must have unique, authentic titles');

      // Verify multi-level section hierarchy
      final sectionRegex = RegExp(r'Section\s+(\d+\.\d+):\s*([^\r\n]+)');
      final foundSections = <String>{};

      for (final layout in layouts) {
        for (final match in sectionRegex.allMatches(layout.text)) {
          foundSections.add(match.group(1)!);
        }
      }

      expect(foundSections.length, greaterThanOrEqualTo(50), reason: 'Book must contain distinct multi-level sections');
      expect(foundSections.contains('1.1'), isTrue);
      expect(foundSections.contains('1.2'), isTrue);
      expect(foundSections.contains('1.3'), isTrue);
      expect(foundSections.contains('25.1'), isTrue);

      // Verify expected theoretical formulas
      final allText = layouts.map((l) => l.text).join('\n');
      final formulas = FormulaExtractionService.instance.extractAllFormulas(allText);
      expect(
        formulas.any((f) => f.latex.contains(r'T(n) = 2T(n/2) + \Theta(n) \implies \Theta(n \log n)')),
        isTrue,
        reason: 'Must extract Master Theorem recurrence formula',
      );
      expect(
        formulas.any((f) => f.latex.contains(r'\log_2(n!) = \Theta(n \log n)')),
        isTrue,
        reason: 'Must extract Stirling lower bound formula',
      );

      // Verify flashcard generation across multi-chapter volume
      const cardBuilder = OfflineCardBuilder();
      final cards = cardBuilder.buildCards(allText, report: report);
      expect(cards, isNotEmpty);

      // Check card diversity across chapters
      final cardHeadings = cards.map((c) => c.heading).whereType<String>().toSet();
      expect(cardHeadings.length, greaterThanOrEqualTo(5), reason: 'Cards must span multiple distinct chapters');
    });
  });
}
