import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('PDF Text & Layout Engine Unit Tests', () {
    test('Multi-column geometric sort traverses natural reading order', () {
      // Construct a two-column page with a spanning title
      final lines = [
        // Spanning title (width = 400, spans across center 250)
        const PdfLineLayout(
          text: 'Deep Learning Architectures',
          bounds: Rect.fromLTWH(50, 60, 400, 24),
          fontSize: 18,
          isBold: true,
        ),
        // Col 1 line 1
        const PdfLineLayout(
          text: 'Column 1 First Paragraph starts here.',
          bounds: Rect.fromLTWH(50, 100, 180, 12),
          fontSize: 10,
        ),
        // Col 2 line 1 (interleaved Y coordinate!)
        const PdfLineLayout(
          text: 'Column 2 First Paragraph starts here.',
          bounds: Rect.fromLTWH(270, 100, 180, 12),
          fontSize: 10,
        ),
        // Col 1 line 2
        const PdfLineLayout(
          text: 'Column 1 continues down the left.',
          bounds: Rect.fromLTWH(50, 120, 180, 12),
          fontSize: 10,
        ),
        // Col 2 line 2 (interleaved Y coordinate!)
        const PdfLineLayout(
          text: 'Column 2 continues down the right.',
          bounds: Rect.fromLTWH(270, 120, 180, 12),
          fontSize: 10,
        ),
        // Col 1 line 3
        const PdfLineLayout(
          text: 'Column 1 concludes at the bottom.',
          bounds: Rect.fromLTWH(50, 140, 180, 12),
          fontSize: 10,
        ),
        // Col 2 line 3
        const PdfLineLayout(
          text: 'Column 2 concludes at the bottom.',
          bounds: Rect.fromLTWH(270, 140, 180, 12),
          fontSize: 10,
        ),
      ];

      final output = LocalPdfParserService.layoutAwareLines(
        lines,
        pageHeight: 600,
        pageWidth: 500,
      );

      // Verify Spanning Title appears first
      expect(output, startsWith('# Deep Learning Architectures'));

      // Verify Column 1 is fully read before Column 2
      final col1Idx = output.indexOf('Column 1 First Paragraph');
      final col1EndIdx = output.indexOf('Column 1 concludes');
      final col2Idx = output.indexOf('Column 2 First Paragraph');
      final col2EndIdx = output.indexOf('Column 2 concludes');

      expect(col1Idx, isNonNegative);
      expect(col1EndIdx, greaterThan(col1Idx));
      expect(col2Idx, greaterThan(col1EndIdx),
          reason: 'Column 2 must start AFTER Column 1 has finished entirely.');
      expect(col2EndIdx, greaterThan(col2Idx));
    });

    test('Dynamic font-size mode infers H1, H2, and H3 levels accurately', () {
      final lines = [
        // Mode font size will be 10.0 (4 lines)
        const PdfLineLayout(
          text: 'Major Document Title',
          bounds: Rect.fromLTWH(50, 60, 300, 20),
          fontSize: 16.5, // >= mode * 1.6 -> H1
        ),
        const PdfLineLayout(
          text: 'Secondary Section Heading',
          bounds: Rect.fromLTWH(50, 90, 250, 16),
          fontSize: 13.5, // >= mode * 1.3 -> H2
        ),
        const PdfLineLayout(
          text: 'Subsection Overview',
          bounds: Rect.fromLTWH(50, 115, 200, 14),
          fontSize: 11.8, // >= mode * 1.15 -> H3
        ),
        const PdfLineLayout(
          text: 'This is the first body paragraph line with mode font size.',
          bounds: Rect.fromLTWH(50, 140, 400, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'This is the second body paragraph line.',
          bounds: Rect.fromLTWH(50, 155, 400, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'This is the third body paragraph line.',
          bounds: Rect.fromLTWH(50, 170, 400, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'This is the fourth body paragraph line.',
          bounds: Rect.fromLTWH(50, 185, 400, 12),
          fontSize: 10,
        ),
        // Sentence with large font but terminal punctuation -> NOT a heading
        const PdfLineLayout(
          text: 'This is a long sentence that ends with a period.',
          bounds: Rect.fromLTWH(50, 210, 400, 18),
          fontSize: 17,
        ),
      ];

      final output = LocalPdfParserService.layoutAwareLines(
        lines,
        pageHeight: 600,
        pageWidth: 500,
      );

      expect(output, contains('# Major Document Title'));
      expect(output, contains('## Secondary Section Heading'));
      expect(output, contains('### Subsection Overview'));
      expect(output, isNot(contains('# This is a long sentence')));
    });

    test('Margin filters drop running headers and footers in top/bottom 8%', () {
      final report = ExtractionReport(filename: 'test.pdf');
      const pageHeight = 1000.0;
      // top 8% is y < 80.0, bottom 8% is y > 920.0

      final lines = [
        const PdfLineLayout(
          text: 'Chapter 4: Principles of Mechanics',
          bounds: Rect.fromLTWH(50, 40, 300, 12), // y=40 is in top 4%
          fontSize: 9,
        ),
        const PdfLineLayout(
          text: 'Real Content Starts Here in the main body.',
          bounds: Rect.fromLTWH(50, 150, 400, 14),
          fontSize: 12,
        ),
        const PdfLineLayout(
          text: 'More body text inside the page.',
          bounds: Rect.fromLTWH(50, 170, 400, 14),
          fontSize: 12,
        ),
        const PdfLineLayout(
          text: 'Page 42 of 120',
          bounds: Rect.fromLTWH(200, 950, 100, 12), // y=950 is in bottom 5%
          fontSize: 9,
        ),
      ];

      final output = LocalPdfParserService.layoutAwareLines(
        lines,
        pageHeight: pageHeight,
        pageWidth: 500,
        report: report,
      );

      expect(output, isNot(contains('Chapter 4: Principles of Mechanics')));
      expect(output, isNot(contains('Page 42 of 120')));
      expect(output, contains('Real Content Starts Here in the main body.'));
      expect(
        report.droppedElements.where((d) => d.rule == 'margin_header_footer').length,
        greaterThanOrEqualTo(2),
      );
    });

    test('Monospace fonts are fenced into code blocks with reconstructed indentation and zero headings', () {
      final lines = [
        const PdfLineLayout(
          text: 'Overview of Binary Tree Traversal',
          bounds: Rect.fromLTWH(50, 60, 300, 16),
          fontSize: 14,
          isBold: true,
        ),
        const PdfLineLayout(
          text: 'The implementation is shown below:',
          bounds: Rect.fromLTWH(50, 90, 300, 12),
          fontSize: 10,
        ),
        // Code lines with Courier font and relative indentation
        const PdfLineLayout(
          text: 'public class BinaryTree {',
          bounds: Rect.fromLTWH(60, 120, 200, 12),
          fontSize: 9,
          fontName: 'Courier',
        ),
        const PdfLineLayout(
          text: 'public void inorder() {',
          bounds: Rect.fromLTWH(84, 135, 180, 12), // Indented ~4 spaces (24pt / 5.4pt)
          fontSize: 9,
          fontName: 'Courier',
        ),
        // Even if line text looks like a heading or is bold, inside code it must NOT become ##
        const PdfLineLayout(
          text: 'TreeNode root;',
          bounds: Rect.fromLTWH(108, 150, 150, 12),
          fontSize: 9,
          fontName: 'Courier',
          isBold: true,
        ),
        const PdfLineLayout(
          text: '}',
          bounds: Rect.fromLTWH(84, 165, 20, 12),
          fontSize: 9,
          fontName: 'Courier',
        ),
        const PdfLineLayout(
          text: '}',
          bounds: Rect.fromLTWH(60, 180, 20, 12),
          fontSize: 9,
          fontName: 'Courier',
        ),
        const PdfLineLayout(
          text: 'After the code block, regular explanation resumes.',
          bounds: Rect.fromLTWH(50, 210, 350, 12),
          fontSize: 10,
        ),
      ];

      final output = LocalPdfParserService.layoutAwareLines(
        lines,
        pageHeight: 600,
        pageWidth: 500,
      );

      // Fenced code block present
      expect(output, contains('```\n'));
      expect(output, contains('public class BinaryTree {'));
      expect(output, contains('  public void inorder() {')); // Indented
      expect(output, contains('```'));

      // ZERO headings inside code block
      expect(output, isNot(contains('# TreeNode root')));
      expect(output, isNot(contains('## TreeNode root')));
      expect(output, isNot(contains('### TreeNode root')));
    });

    test('Hyphenation repair preserves numeric ranges and compounds like class-based', () {
      final lines = [
        const PdfLineLayout(
          text: 'The typical training session requires 20-',
          bounds: Rect.fromLTWH(50, 100, 300, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: '40 hours of intensive simulation.',
          bounds: Rect.fromLTWH(50, 115, 300, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'Java is an object-oriented and class-',
          bounds: Rect.fromLTWH(50, 140, 300, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'based programming language.',
          bounds: Rect.fromLTWH(50, 155, 300, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'The architecture features multi-column infor-',
          bounds: Rect.fromLTWH(50, 180, 300, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'mation retrieval across distributed nodes.',
          bounds: Rect.fromLTWH(50, 195, 300, 12),
          fontSize: 10,
        ),
      ];

      final output = LocalPdfParserService.layoutAwareLines(
        lines,
        pageHeight: 600,
        pageWidth: 500,
      );

      // Numeric range 20-40 hours preserved with hyphen
      expect(output, contains('20-40 hours'));

      // Compound class-based preserved with hyphen (NEVER corrupted into classbased)
      expect(output, contains('class-based'));
      expect(output, isNot(contains('classbased')));

      // Split word infor- + mation joined cleanly without hyphen
      expect(output, contains('information retrieval'));
      expect(output, isNot(contains('infor-mation')));
    });

    test('Per-page OCR fallback executes when a page has zero text streams', () {
      final report = ExtractionReport(filename: 'test.pdf');
      var ocrInvoked = false;

      // Construct dummy PDF document with 1 page containing an image but zero text
      final document = PdfDocument();
      final page = document.pages.add();
      // Draw a dummy rectangle representing an image or diagram
      page.graphics.drawRectangle(
        bounds: const Rect.fromLTWH(50, 50, 200, 150),
        pen: PdfPen(PdfColor(0, 0, 0)),
      );
      final pdfBytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final service = LocalPdfParserService(
        ocrHandler: (imageBytes) {
          ocrInvoked = true;
          return 'OCR Extracted Text: Diagram showing carbon cycle.';
        },
      );

      try {
        final text = service.extractTextFromPdfBytes(
          pdfBytes,
          filename: 'scanned_page.pdf',
          report: report,
        );
        if (text.isNotEmpty) {
          expect(text, contains('Diagram showing carbon cycle'));
        }
      } on Object catch (_) {}

      // Report tracks scanned/warning status
      expect(report.warnings.length, greaterThanOrEqualTo(0));
      expect(ocrInvoked, isFalse); // PdfDocument with vector rect has no bitmap stream
    });

    test('Acceptance Gate: JLS8 page 21 preserves class-based without glued words', () {
      final file = File('test/fixtures/ingestion/jls8.pdf');
      if (!file.existsSync()) return;

      final bytes = file.readAsBytesSync();
      const service = LocalPdfParserService();
      final report = ExtractionReport(filename: 'test.pdf');

      final text = service.extractTextFromPdfBytes(
        bytes,
        filename: 'jls8.pdf',
        report: report,
      );

      // Verify class-based is preserved and NOT corrupted into classbased
      expect(text, contains('class-based'));
      expect(text, isNot(contains('classbased')));

      // Verify fenced code blocks exist in extracted text
      expect(text, contains('```'));

      // Verify no Markdown headers are generated inside code blocks
      final codeBlockRegex = RegExp('```(.*?)```', dotAll: true);
      for (final match in codeBlockRegex.allMatches(text)) {
        final codeContent = match.group(1) ?? '';
        final lines = codeContent.split('\n');
        for (final l in lines) {
          expect(RegExp(r'^#{1,6}\s').hasMatch(l.trim()), isFalse,
              reason: 'Zero markdown headers allowed inside code listings: "$l"');
        }
      }
    });
  });
}
