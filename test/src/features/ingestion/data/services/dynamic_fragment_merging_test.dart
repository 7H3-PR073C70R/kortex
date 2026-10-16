import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';

void main() {
  group('Dynamic Font-Relative Gap Threshold & Fragment Merging', () {
    test('dynamic threshold scales with font size for small and large fonts', () {
      // 1. Small font (8pt): gap of 1.7pt is a valid word space (1.7 >= 0.20 * 8.0 = 1.6)
      // Old fixed 2.0pt threshold would fail to inject space; dynamic threshold succeeds.
      const smallFrag1 = PdfLineLayout(
        text: 'footnote',
        bounds: Rect.fromLTWH(50, 100, 40, 8),
        fontSize: 8,
        fontName: 'Times',
      );
      const smallFrag2 = PdfLineLayout(
        text: 'reference',
        bounds: Rect.fromLTWH(91.7, 100, 45, 8), // gap = 91.7 - 90.0 = 1.7
        fontSize: 8,
        fontName: 'Times',
      );

      final smallMerged = LocalPdfParserService.combineLineFragments([smallFrag1, smallFrag2]);
      expect(smallMerged.text, equals('footnote reference'));

      // 2. Large font (24pt): kerning gap of 2.5pt is NOT a word boundary (2.5 < 0.20 * 24.0 = 4.8)
      // Old fixed 2.0pt threshold would falsely inject space; dynamic threshold preserves word.
      const largeFrag1 = PdfLineLayout(
        text: 'Chapt',
        bounds: Rect.fromLTWH(50, 50, 70, 24),
        fontSize: 24,
        fontName: 'Helvetica',
      );
      const largeFrag2 = PdfLineLayout(
        text: 'er',
        bounds: Rect.fromLTWH(122.5, 50, 25, 24), // gap = 122.5 - 120.0 = 2.5
        fontSize: 24,
        fontName: 'Helvetica',
      );

      final largeMerged = LocalPdfParserService.combineLineFragments([largeFrag1, largeFrag2]);
      expect(largeMerged.text, equals('Chapter'));
    });

    test('calculates dominant font properties from majority character fragment', () {
      const quoteFrag = PdfLineLayout(
        text: '"',
        bounds: Rect.fromLTWH(50, 100, 5, 11),
        fontSize: 8,
        fontName: 'Courier',
      );
      const bodyFrag = PdfLineLayout(
        text: 'The Java programming language is a general-purpose language',
        bounds: Rect.fromLTWH(58, 100, 320, 11),
        fontSize: 11,
        fontName: 'Times-Roman',
      );

      final merged = LocalPdfParserService.combineLineFragments([quoteFrag, bodyFrag]);
      // Rather than blindly inheriting Courier 8.0 from first fragment, dominant font is adopted
      expect(merged.fontSize, equals(11.0));
      expect(merged.fontName, equals('Times-Roman'));
      expect(merged.text, equals('"The Java programming language is a general-purpose language'));
    });

    test('handles font transitions (regular -> monospace code) with word boundaries', () {
      const proseFrag = PdfLineLayout(
        text: 'stored in the',
        bounds: Rect.fromLTWH(90, 255.3, 176.7, 9),
        fontSize: 9,
        fontName: 'Times',
      );
      const codeFrag = PdfLineLayout(
        text: 'class',
        bounds: Rect.fromLTWH(269, 256.1, 24, 8), // gap = 2.3 pt
        fontSize: 8,
        fontName: 'Courier',
      );

      final merged = LocalPdfParserService.combineLineFragments([proseFrag, codeFrag]);
      expect(merged.text, equals('stored in the class'));
    });

    test('does not inject spaces before closing punctuation or after opening punctuation', () {
      const codeFrag = PdfLineLayout(
        text: 'System.out.println()',
        bounds: Rect.fromLTWH(50, 100, 120, 10),
        fontSize: 10,
        fontName: 'Courier',
      );
      const semicolonFrag = PdfLineLayout(
        text: ';',
        bounds: Rect.fromLTWH(171, 100, 5, 10), // gap = 1.0 pt
        fontSize: 10,
        fontName: 'Times',
      );

      final merged = LocalPdfParserService.combineLineFragments([codeFrag, semicolonFrag]);
      expect(merged.text, equals('System.out.println();'));
    });

    test('preserves hyphenated compound across fragments without inserting space', () {
      const prefixFrag = PdfLineLayout(
        text: 'class-',
        bounds: Rect.fromLTWH(50, 100, 35, 10),
        fontSize: 10,
        fontName: 'Times',
      );
      const suffixFrag = PdfLineLayout(
        text: 'based',
        bounds: Rect.fromLTWH(87.5, 100, 35, 10), // gap = 2.5 pt
        fontSize: 10,
        fontName: 'Times',
      );

      final merged = LocalPdfParserService.combineLineFragments([prefixFrag, suffixFrag]);
      expect(merged.text, equals('class-based'));
    });

    test('repairGluedWordTransitions unit tests', () {
      expect(LocalPdfParserService.repairGluedWordTransitions('since thearray creation expression'),
          equals('since the array creation expression'));
      expect(LocalPdfParserService.repairGluedWordTransitions('over thedirect supertype relation'),
          equals('over the direct supertype relation'));
      expect(LocalPdfParserService.repairGluedWordTransitions('simplifying assumption abovethat loose'),
          equals('simplifying assumption above that loose'));
      expect(LocalPdfParserService.repairGluedWordTransitions('Thedirect supertype is'),
          equals('The direct supertype is'));
      expect(LocalPdfParserService.repairGluedWordTransitions('values of all thetypes Ti'),
          equals('values of all the types Ti'));

      // Preserves valid words starting with the / above / using
      expect(LocalPdfParserService.repairGluedWordTransitions('theme theory theorem therefore their there'),
          equals('theme theory theorem therefore their there'));
      // Preserves camelCase identifiers
      expect(LocalPdfParserService.repairGluedWordTransitions('final theArray = [];'),
          equals('final theArray = [];'));
    });

    test('Acceptance Gate: JLS8 eliminates target glued transitions', () {
      final file = File('test/fixtures/ingestion/jls8.pdf');
      if (!file.existsSync()) return;

      const service = LocalPdfParserService();
      final text = service.extractTextFromPdfBytes(
        file.readAsBytesSync(),
        filename: 'jls8.pdf',
      );

      final forbidden = [
        'thearray',
        'thearrays',
        'thedirect',
        'abovethat',
        'usingthat',
        'theclass',
        'theclasses',
        'themethod',
        'themethods',
        'thetype',
        'thetypes',
      ];

      for (final target in forbidden) {
        expect(
          text.contains(target),
          isFalse,
          reason: 'JLS8 extraction must eliminate glued transition "$target"',
        );
      }

      // Ensure class-based is preserved and not broken into class- based or classbased
      expect(text, contains('class-based'));
      expect(text, isNot(contains('classbased')));
      expect(text, isNot(contains('class- based')));
    });
  });
}
