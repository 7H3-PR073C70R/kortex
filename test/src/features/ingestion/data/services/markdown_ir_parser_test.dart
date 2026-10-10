import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/markdown_ir_parser.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

void main() {
  group('MarkdownIrParser Unit Tests', () {
    const parser = MarkdownIrParser();

    test('parses biology_cell_respiration.md with 100% block coverage', () {
      final file = File('test/fixtures/ingestion/biology_cell_respiration.md');
      final content = file.readAsStringSync();

      final ir = parser.parse(
        markdown: content,
        filename: 'biology_cell_respiration.md',
      );

      expect(ir.filename, equals('biology_cell_respiration.md'));
      expect(ir.docId, isNotEmpty);
      expect(ir.blocks, isNotEmpty);

      // Verify headings
      final headings = ir.headings;
      expect(headings.map((h) => h.text).toList(), equals([
        'Cellular Respiration',
        'Overview',
        'Glycolysis',
        'Key Terms',
        'Stages in Order',
        'Formula',
      ]));
      expect(headings[0].level, equals(1));
      expect(headings[1].level, equals(2));

      // Verify paragraphs
      final paragraphs = ir.paragraphs;
      expect(paragraphs.length, greaterThanOrEqualTo(2));
      expect(paragraphs.first.text, contains('Cellular respiration is the process'));
      expect(paragraphs.first.sentences.length, equals(3));
      expect(paragraphs[1].text, contains('Glycolysis is the first stage'));

      // Verify lists: Key Terms (unordered) and Stages in Order (ordered)
      final lists = ir.lists;
      expect(lists.length, equals(2));
      final unorderedList = lists.first;
      expect(unorderedList.isOrdered, isFalse);
      expect(unorderedList.items.length, equals(4));
      expect(unorderedList.items.first.text, contains('ATP: The main energy currency'));

      final orderedList = lists[1];
      expect(orderedList.isOrdered, isTrue);
      expect(orderedList.items.length, equals(4));
      expect(orderedList.items[0].text, equals('Glycolysis'));
      expect(orderedList.items[3].text, equals('Electron transport chain'));

      // Verify formula block
      final mathBlocks = ir.mathBlocks;
      expect(mathBlocks.length, equals(1));
      expect(mathBlocks.first.latex, contains('C6H12O6 + 6O2'));

      // Verify hierarchical section provenance on the formula block
      expect(mathBlocks.first.provenance.sectionPath, equals([
        'Cellular Respiration',
        'Formula',
      ]));

      // Verify reading order is strictly incrementing
      for (var i = 0; i < ir.blocks.length; i++) {
        expect(ir.blocks[i].provenance.readingOrder, equals(i));
      }
    });

    test('parses flutter_state_notes.md with code block fidelity and provenance', () {
      final file = File('test/fixtures/ingestion/flutter_state_notes.md');
      final content = file.readAsStringSync();

      final ir = parser.parse(
        markdown: content,
        filename: 'flutter_state_notes.md',
      );

      expect(ir.blocks, isNotEmpty);

      // Verify code block
      final codeBlocks = ir.codeBlocks;
      expect(codeBlocks.length, equals(1));
      final dartCode = codeBlocks.first;
      expect(dartCode.language, equals('dart'));
      expect(dartCode.code, contains('class Counter extends StatefulWidget'));
      expect(dartCode.code, contains('State<Counter> createState() => _CounterState();'));
      expect(dartCode.lineCount, equals(5));

      // Verify tips list
      final lists = ir.lists;
      expect(lists.length, equals(1));
      expect(lists.first.items.length, equals(3));
      expect(lists.first.items[0].text, contains('Keep build methods free of side effects.'));
    });

    test('parses tutorial_dart_concurrency_isolates.md preserving code indentation and section paths', () {
      final file = File('test/fixtures/ingestion/tutorial_dart_concurrency_isolates.md');
      final content = file.readAsStringSync();

      final ir = parser.parse(
        markdown: content,
        filename: 'tutorial_dart_concurrency_isolates.md',
      );

      // Headings check
      final headings = ir.headings;
      expect(headings.length, equals(3));
      expect(headings[0].text, equals('High-Performance Concurrency with Dart Isolates'));
      expect(headings[1].text, equals('1. Threading Model and Memory Isolation'));
      expect(headings[2].text, equals('2. Bidirectional Isolate Handshake Pattern'));

      // Verify hierarchical section path on the code block
      final codeBlocks = ir.codeBlocks;
      expect(codeBlocks.length, equals(1));
      expect(codeBlocks.first.provenance.sectionPath, equals([
        'High-Performance Concurrency with Dart Isolates',
        '1. Threading Model and Memory Isolation',
      ]));

      // Verify indentation and newlines are preserved byte-for-byte in code
      expect(codeBlocks.first.code, contains('  final int id;'));
      expect(codeBlocks.first.code, contains('    sum += n * n;'));
      expect(codeBlocks.first.code, contains('Future<int> computeInIsolate(List<int> numbers) async {'));
    });

    test('parses Markdown tables with headers and rows into TableBlock', () {
      const markdownTable = '''
# Benchmark Metrics

| Framework | Latency (ms) | Memory (MB) |
| :--- | :--- | :--- |
| Kortex Engine | 12.4 | 48 |
| Legacy Parser | 89.2 | 182 |
| Raw Fallback | 142.0 | 250 |
''';

      final ir = parser.parse(markdown: markdownTable);
      final tables = ir.tables;
      expect(tables.length, equals(1));

      final table = tables.first;
      expect(table.headers, equals(['Framework', 'Latency (ms)', 'Memory (MB)']));
      expect(table.rows.length, equals(3));
      expect(table.rows[0], equals(['Kortex Engine', '12.4', '48']));
      expect(table.rows[1], equals(['Legacy Parser', '89.2', '182']));
      expect(table.rows[2], equals(['Raw Fallback', '142.0', '250']));
      expect(table.provenance.sectionPath, equals(['Benchmark Metrics']));
    });

    test('parses markdown figures into FigureBlock with caption and label', () {
      const markdownFig = '''
# System Architecture

![Figure 4: Dataflow Pipeline Overview](https://example.com/assets/arch.png)

This diagram shows the complete end-to-end ingestion pipeline.
''';

      final ir = parser.parse(markdown: markdownFig);
      final figures = ir.figures;
      expect(figures.length, equals(1));

      final fig = figures.first;
      expect(fig.caption, equals('Figure 4: Dataflow Pipeline Overview'));
      expect(fig.label, equals('Figure 4'));
      expect(fig.imageRef, equals('https://example.com/assets/arch.png'));
      expect(fig.provenance.sectionPath, equals(['System Architecture']));
    });

    test('parses LaTeX display math blocks with delimiters into MathBlock', () {
      const markdownMath = r'''
# Physics Notes

$$
E = \frac{m c^2}{\sqrt{1 - \frac{v^2}{c^2}}}
$$
''';

      final ir = parser.parse(markdown: markdownMath);
      final mathBlocks = ir.mathBlocks;
      expect(mathBlocks.length, equals(1));
      expect(mathBlocks.first.isDisplay, isTrue);
      expect(mathBlocks.first.latex, contains(r'\frac{m c^2}'));
      expect(mathBlocks.first.provenance.sectionPath, equals(['Physics Notes']));
    });

    test('DocumentIR serialization and deserialization roundtrip maintains 100% fidelity', () {
      final file = File('test/fixtures/ingestion/biology_cell_respiration.md');
      final content = file.readAsStringSync();
      final originalIr = parser.parse(markdown: content);

      final json = originalIr.toJson();
      final roundTripIr = DocumentIR.fromJson(json);

      expect(roundTripIr.docId, equals(originalIr.docId));
      expect(roundTripIr.filename, equals(originalIr.filename));
      expect(roundTripIr.blockCount, equals(originalIr.blockCount));
      expect(roundTripIr.headings.length, equals(originalIr.headings.length));
      expect(roundTripIr.paragraphs.length, equals(originalIr.paragraphs.length));
      expect(roundTripIr.lists.length, equals(originalIr.lists.length));
      expect(roundTripIr.mathBlocks.length, equals(originalIr.mathBlocks.length));

      for (var i = 0; i < originalIr.blocks.length; i++) {
        final b1 = originalIr.blocks[i];
        final b2 = roundTripIr.blocks[i];
        expect(b2.rawText, equals(b1.rawText));
        expect(b2.provenance.page, equals(b1.provenance.page));
        expect(b2.provenance.readingOrder, equals(b1.provenance.readingOrder));
        expect(b2.provenance.sectionPath, equals(b1.provenance.sectionPath));
      }
    });
  });
}
