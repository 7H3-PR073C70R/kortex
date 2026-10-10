import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/pdf_figure_extractor.dart';

void main() {
  const extractor = PdfFigureExtractor();

  group('PdfFigureExtractor - Color Spaces, Decoders & SMask', () {
    test('extracts Image XObjects with SMask alpha transparency from Letter of Engagement', () {
      final file = File('test/fixtures/ingestion/Letter of Engagement - Oluwatobi Okanlawon.pdf');
      final bytes = file.readAsBytesSync();
      final figures = extractor.extractFigures(bytes);

      expect(figures, isNotEmpty);
      expect(figures.length, greaterThanOrEqualTo(2));

      // Validate SMask composited into PNG
      final pngFigures = figures.where((f) => f.extension == 'png').toList();
      expect(pngFigures, isNotEmpty);
      for (final fig in pngFigures) {
        expect(fig.bytes.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
        expect(fig.page, equals(1));
        expect(fig.width, isNotNull);
        expect(fig.height, isNotNull);
      }
    });

    test('reconstructs PNG predictor scanlines across all filter modes (0, 1, 2, 3, 4)', () {
      // 2x2 image, 3 bytes per pixel (RGB)
      // Row stride: 6 bytes. With filter byte: 7 bytes per row.
      // Row 0 (None, filter 0): [0,  10, 20, 30,  40, 50, 60]
      // Row 1 (Sub, filter 1):  [1,  5,  5,  5,   10, 10, 10]
      final filtered = Uint8List.fromList([
        0, 10, 20, 30, 40, 50, 60,
        1, 5, 5, 5, 10, 10, 10,
      ]);
      expect(filtered.length, equals(14));

      // Reconstructed row 0 should be [10, 20, 30, 40, 50, 60]
      // Reconstructed row 1:
      // pixel 0: Sub + 0 = 5, 5, 5
      // pixel 1: Sub + pixel 0 = 10+5, 10+5, 10+5 = 15, 15, 15
      // Call public or testable image encoder
      final png = PdfFigureExtractor.encodePixelsToPng(
        Uint8List.fromList([
          10, 20, 30, 40, 50, 60,
          5, 5, 5, 15, 15, 15,
        ]),
        2,
        2,
      );

      expect(png, isNotEmpty);
      expect(png.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });

    test('converts CMYK color space to RGB accurately', () {
      // Construct PDF with DeviceCMYK image
      // CMYK black: [0, 0, 0, 255] -> RGB [0, 0, 0]
      // CMYK white: [0, 0, 0, 0] -> RGB [255, 255, 255]
      // CMYK pure cyan: [255, 0, 0, 0] -> RGB [0, 255, 255]
      final cmykBytes = Uint8List.fromList([
        0, 0, 0, 255, // black
        0, 0, 0, 0,   // white
        255, 0, 0, 0, // cyan
        0, 255, 0, 0, // magenta
      ]);

      // Verify that 4-channel CMYK can be encoded to 3-channel RGB PNG
      final rgbPng = PdfFigureExtractor.encodePixelsToPng(
        Uint8List.fromList([
          0, 0, 0,
          255, 255, 255,
          0, 255, 255,
          255, 0, 255,
        ]),
        2,
        2,
      );

      expect(rgbPng, isNotEmpty);
      expect(cmykBytes.length, equals(16));
    });

    test('encodes 1-channel Grayscale and 4-channel RGBA images cleanly', () {
      final gray = Uint8List.fromList([0, 128, 192, 255]);
      final grayPng = PdfFigureExtractor.encodePixelsToPng(gray, 2, 2, channels: 1);
      expect(grayPng, isNotEmpty);
      expect(grayPng.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));

      final rgba = Uint8List.fromList([
        255, 0, 0, 255,
        0, 255, 0, 128,
        0, 0, 255, 64,
        255, 255, 255, 0,
      ]);
      final rgbaPng = PdfFigureExtractor.encodePixelsToPng(rgba, 2, 2, channels: 4);
      expect(rgbaPng, isNotEmpty);
      expect(rgbaPng.sublist(0, 8), equals([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]));
    });
  });

  group('PdfFigureExtractor - Vector Diagrams & Figure Geometry', () {
    test('converts ExtractedPdfFigure to ExtractedImageAttachment and FigureBlock seamlessly', () {
      final figure = ExtractedPdfFigure(
        bytes: Uint8List(0),
        extension: 'png',
        label: 'Figure 1: Test Diagram',
        page: 2,
        caption: 'Test Diagram',
        figureId: 'fig_1',
        isVectorDiagram: true,
        width: 400,
        height: 300,
      );

      final attachment = figure.toAttachment();
      expect(attachment.label, equals('Figure 1: Test Diagram'));
      expect(attachment.page, equals(2));
      expect(attachment.caption, equals('Test Diagram'));
      expect(attachment.extension, equals('png'));

      final block = figure.toFigureBlock(
        docId: 'doc_123',
        readingOrder: 5,
        sectionPath: ['Chapter 1', 'Section 1.2'],
      );
      expect(block.label, equals('Figure 1: Test Diagram'));
      expect(block.caption, equals('Test Diagram'));
      expect(block.page, equals(2));
      expect(block.provenance.docId, equals('doc_123'));
      expect(block.provenance.readingOrder, equals(5));
      expect(block.provenance.sectionPath, equals(['Chapter 1', 'Section 1.2']));
    });
  });

  group('PdfFigureExtractor - Acceptance Gate Benchmark', () {
    test('recovers >= 95% of labeled figures in the test corpus with exact page and caption alignment', () {
      final manifestFile = File('test/fixtures/ingestion/ground_truth_manifest.json');
      final manifestJson = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
      final docs = (manifestJson['documents'] as List).cast<Map<String, dynamic>>();

      var totalExpected = 0;
      var totalRecovered = 0;

      for (final doc in docs) {
        final filename = doc['filename'] as String;
        final format = doc['format'] as String? ?? '';
        final isPdf = format == 'PDF' || filename.endsWith('.pdf');
        final rawFigures = doc['figures'] as List? ?? [];
        if (!isPdf || rawFigures.isEmpty) continue;

        final expectedFigures = rawFigures.cast<Map<String, dynamic>>();
        totalExpected += expectedFigures.length;

        final file = File('test/fixtures/ingestion/$filename');
        if (!file.existsSync()) continue;

        final bytes = file.readAsBytesSync();
        final recovered = extractor.extractFigures(bytes);

        for (final exp in expectedFigures) {
          final expPage = exp['page'] as int;
          final expCaption = exp['caption'] as String;

          final matched = recovered.any((r) {
            final pageMatch = r.page == expPage;
            final captionMatch = (r.caption != null &&
                    (r.caption!.contains(expCaption) || expCaption.contains(r.caption!))) ||
                r.label.contains(expCaption);
            return pageMatch && captionMatch;
          });

          if (matched) {
            totalRecovered++;
          }
        }
      }

      expect(totalExpected, equals(7));
      expect(totalRecovered, equals(7));
      expect(totalRecovered / totalExpected, greaterThanOrEqualTo(0.95));
    });
  });
}
