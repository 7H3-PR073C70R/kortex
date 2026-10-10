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

    test('parses code blocks with specialized language tags (c#, c++, f#, obj-c)', () {
      const csharpMarkdown = '''
# C# Service

```c#
public class UserService {
    public string Name { get; set; }
}
```

```c++
#include <iostream>
int main() { return 0; }
```

```f#
let square x = x * x
```
''';

      final ir = parser.parse(markdown: csharpMarkdown);
      final codeBlocks = ir.codeBlocks;
      expect(codeBlocks.length, equals(3));
      expect(codeBlocks[0].language, equals('c#'));
      expect(codeBlocks[0].code, contains('public class UserService'));
      expect(codeBlocks[1].language, equals('c++'));
      expect(codeBlocks[1].code, contains('#include <iostream>'));
      expect(codeBlocks[2].language, equals('f#'));
      expect(codeBlocks[2].code, contains('let square x = x * x'));
    });

    test('supports variable-length fences (~~~~, ````) and nested fences', () {
      const nestedMarkdown = '''
# Markdown Tutorial

````markdown
Here is an example code block:
```dart
void main() => print("Hello");
```
````

~~~~python
def compute(x):
    return x * 2
~~~~
''';

      final ir = parser.parse(markdown: nestedMarkdown);
      final codeBlocks = ir.codeBlocks;
      expect(codeBlocks.length, equals(2));
      expect(codeBlocks[0].language, equals('markdown'));
      expect(codeBlocks[0].code, contains('```dart'));
      expect(codeBlocks[0].code, contains('void main() => print("Hello");'));
      expect(codeBlocks[1].language, equals('python'));
      expect(codeBlocks[1].code, contains('def compute(x):'));
    });

    test('normalizes CRLF line endings without stray carriage returns', () {
      const crlfMarkdown = '# Title\r\n\r\nParagraph line 1\r\nParagraph line 2\r\n\r\n```dart\r\nfinal x = 42;\r\n```\r\n';
      final ir = parser.parse(markdown: crlfMarkdown);

      expect(ir.headings.first.text, equals('Title'));
      expect(ir.paragraphs.first.text, equals('Paragraph line 1 Paragraph line 2'));
      expect(ir.codeBlocks.first.code, equals('final x = 42;'));
      expect(ir.codeBlocks.first.code.contains('\r'), isFalse);
    });

    test('resolves relative image URLs against basePath', () {
      const markdownImages = '''
# Architecture

![System Overview](./diagrams/system.png)
![External Cloud](https://cdn.example.com/cloud.svg)
''';

      final ir = parser.parse(
        markdown: markdownImages,
        basePath: '/workspace/projects/kortex/docs',
      );

      final figures = ir.figures;
      expect(figures.length, equals(2));
      expect(figures[0].imageRef, equals('/workspace/projects/kortex/docs/diagrams/system.png'));
      expect(figures[1].imageRef, equals('https://cdn.example.com/cloud.svg'));
    });

    test('distinguishes currency notation from mathematical formulas', () {
      const currencyMarkdown = r'''
# Pricing Plans

Enterprise licenses cost $1,500 per month.

The starter plan is $50 to $100 depending on usage.

Total funding reached $20 million in Series A.
''';

      final ir = parser.parse(markdown: currencyMarkdown);

      // Verify that no currency lines were misclassified as MathBlock
      expect(ir.mathBlocks, isEmpty);
      expect(ir.paragraphs.length, equals(3));
      expect(ir.paragraphs[0].text, contains(r'Enterprise licenses cost $1,500 per month.'));
      expect(ir.paragraphs[1].text, contains(r'The starter plan is $50 to $100 depending on usage.'));
      expect(ir.paragraphs[2].text, contains(r'Total funding reached $20 million in Series A.'));
    });
  });
}
