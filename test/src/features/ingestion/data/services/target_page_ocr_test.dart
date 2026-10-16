import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/pdf_figure_extractor.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('Target-Page OCR Fallback (Task 2.2)', () {
    // Helper to generate a solid color PNG bitmap of given dimensions
    Uint8List createSolidPng(int width, int height, {required int r, required int g, required int b}) {
      final pixels = Uint8List(width * height * 3);
      for (var i = 0; i < width * height; i++) {
        pixels[i * 3] = r;
        pixels[i * 3 + 1] = g;
        pixels[i * 3 + 2] = b;
      }
      return PdfFigureExtractor.encodePixelsToPng(pixels, width, height);
    }

    test('multi-page scanned PDF with embedded images assigns page-specific OCR text', () {
      final img1Png = createSolidPng(200, 150, r: 255, g: 0, b: 0); // Red
      final img2Png = createSolidPng(200, 150, r: 0, g: 0, b: 255); // Blue

      final doc = PdfDocument();
      // Page 1: Scanned image with red bitmap
      final page1 = doc.pages.add();
      page1.graphics.drawImage(
        PdfBitmap(img1Png),
        const Rect.fromLTWH(20, 20, 200, 150),
      );

      // Page 2: Scanned image with blue bitmap
      final page2 = doc.pages.add();
      page2.graphics.drawImage(
        PdfBitmap(img2Png),
        const Rect.fromLTWH(20, 20, 200, 150),
      );

      final pdfBytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      final invocations = <int, List<int>>{};
      var callCount = 0;

      final service = LocalPdfParserService(
        ocrHandler: (imageBytes) {
          callCount++;
          // Identify which image was passed based on pixel probe
          // Red image has byte[0] == 255 or contains red pixels
          // Blue image has blue pixels
          if (listEquals(imageBytes, img1Png)) {
            invocations[1] = imageBytes;
            return 'Page 1 OCR Text: Introduction to Quantum Mechanics';
          } else if (listEquals(imageBytes, img2Png)) {
            invocations[2] = imageBytes;
            return 'Page 2 OCR Text: Schrödinger Wave Equation';
          }
          return 'Unknown Image OCR';
        },
      );

      final report = ExtractionReport(filename: 'scanned_two_page.pdf');
      final layouts = service.extractPageLayoutsFromPdfBytes(
        pdfBytes,
        filename: 'scanned_two_page.pdf',
        report: report,
      );

      // Both pages must be extracted
      expect(layouts.length, equals(2));

      // Page 1 assertions
      expect(layouts[0].pageIndex, equals(1));
      expect(layouts[0].text, contains('Introduction to Quantum Mechanics'));
      expect(layouts[0].text, isNot(contains('Schrödinger Wave Equation')));

      // Page 2 assertions - MUST NEVER be Page 1's image text
      expect(layouts[1].pageIndex, equals(2));
      expect(layouts[1].text, contains('Schrödinger Wave Equation'));
      expect(layouts[1].text, isNot(contains('Introduction to Quantum Mechanics')));

      // OCR must have been called exactly once per page
      expect(callCount, equals(2));
      expect(invocations.containsKey(1), isTrue);
      expect(invocations.containsKey(2), isTrue);
    });

    test('multi-page document where Page 1 has text and Page 2 is scanned image-only', () {
      final img2Png = createSolidPng(200, 150, r: 0, g: 255, b: 0); // Green

      final doc = PdfDocument();
      // Page 1: Regular text stream
      final page1 = doc.pages.add();
      page1.graphics.drawString(
        'Chapter 1: Principles of Photosynthesis in Plant Biology.',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 20, 400, 50),
      );

      // Page 2: Image-only scanned page
      final page2 = doc.pages.add();
      page2.graphics.drawImage(
        PdfBitmap(img2Png),
        const Rect.fromLTWH(20, 20, 200, 150),
      );

      final pdfBytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      var ocrCalledCount = 0;
      final service = LocalPdfParserService(
        ocrHandler: (imageBytes) {
          ocrCalledCount++;
          return 'Page 2 Scanned OCR: Light-dependent reactions generate ATP and NADPH.';
        },
      );

      final report = ExtractionReport(filename: 'hybrid_doc.pdf');
      final layouts = service.extractPageLayoutsFromPdfBytes(
        pdfBytes,
        filename: 'hybrid_doc.pdf',
        report: report,
      );

      expect(layouts.length, equals(2));

      // Page 1 was parsed via text extractor
      expect(layouts[0].pageIndex, equals(1));
      expect(layouts[0].text, contains('Chapter 1: Principles of Photosynthesis'));

      // Page 2 was parsed via OCR fallback
      expect(layouts[1].pageIndex, equals(2));
      expect(layouts[1].text, contains('Light-dependent reactions generate ATP and NADPH'));

      // OCR was ONLY called for Page 2, not Page 1
      expect(ocrCalledCount, equals(1));
    });

    test('Page without embedded bitmap rasterizes page viewport rather than using Page 1 image', () {
      final img1Png = createSolidPng(200, 150, r: 255, g: 128, b: 0); // Orange

      final doc = PdfDocument();
      // Page 1: Scanned image
      final page1 = doc.pages.add();
      page1.graphics.drawImage(
        PdfBitmap(img1Png),
        const Rect.fromLTWH(20, 20, 200, 150),
      );

      // Page 2: Empty / vector-only page (no bitmap stream)
      final page2 = doc.pages.add();
      page2.graphics.drawRectangle(
        bounds: const Rect.fromLTWH(30, 30, 150, 100),
        pen: PdfPen(PdfColor(0, 0, 0)),
      );

      final pdfBytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      final ocrInputs = <Uint8List>[];

      final service = LocalPdfParserService(
        ocrHandler: (imageBytes) {
          ocrInputs.add(imageBytes);
          if (listEquals(imageBytes, img1Png)) {
            return 'Page 1 Figure Diagram: Thermodynamic Cycles';
          }
          return 'Page 2 Viewport Rasterized OCR: Hand-drawn vector state machine';
        },
      );

      final report = ExtractionReport(filename: 'vector_fallback.pdf');
      final layouts = service.extractPageLayoutsFromPdfBytes(
        pdfBytes,
        filename: 'vector_fallback.pdf',
        report: report,
      );

      expect(layouts.length, equals(2));

      // Page 1 used img1Png
      expect(layouts[0].pageIndex, equals(1));
      expect(layouts[0].text, contains('Thermodynamic Cycles'));

      // Page 2 rasterized its viewport and NEVER received img1Png
      expect(layouts[1].pageIndex, equals(2));
      expect(layouts[1].text, contains('Hand-drawn vector state machine'));
      expect(layouts[1].text, isNot(contains('Thermodynamic Cycles')));

      // Verify that OCR input for Page 2 was NOT img1Png
      expect(ocrInputs.length, equals(2));
      expect(listEquals(ocrInputs[0], img1Png), isTrue);
      expect(listEquals(ocrInputs[1], img1Png), isFalse);
    });

    test('rasterizePageViewport creates valid PNG bytes of expected dimensions', () {
      final doc = PdfDocument();
      final page = doc.pages.add();
      page.graphics.drawRectangle(
        bounds: const Rect.fromLTWH(40, 40, 200, 150),
        pen: PdfPen(PdfColor(50, 50, 50)),
      );
      final pdfBytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();

      const service = LocalPdfParserService();
      final viewportPng = service.rasterizePageViewport(pdfBytes, 1, width: 400, height: 300);

      expect(viewportPng.isNotEmpty, isTrue);
      // Valid PNG signature: 0x89, 0x50, 0x4E, 0x47
      expect(viewportPng[0], equals(0x89));
      expect(viewportPng[1], equals(0x50));
      expect(viewportPng[2], equals(0x4E));
      expect(viewportPng[3], equals(0x47));
    });
  });
}
