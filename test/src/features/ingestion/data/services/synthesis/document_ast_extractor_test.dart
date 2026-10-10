import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/document_ast_extractor.dart';

void main() {
  const extractor = DocumentAstExtractor();

  group('DocumentAstExtractor - Layer 1', () {
    test('isolates fenced code blocks and replaces them with placeholders', () {
      const input = '''
# State Management

Here is a simple counter notifier:

```dart
class CounterNotifier extends ValueNotifier<int> {
  CounterNotifier() : super(0);
  void increment() => value++;
}
```

This class manages the reactive state.
''';

      final ast = extractor.extract(input, filename: 'notes.md');

      expect(ast.registry.artifacts.length, equals(1));
      final artifact = ast.registry.artifacts.values.first;
      expect(artifact.type, equals(ArtifactType.code));
      expect(artifact.language, equals('dart'));
      expect(artifact.rawContent, contains('class CounterNotifier'));

      // Check code block node
      final codeNodes = ast.nodes.whereType<CodeBlockNode>().toList();
      expect(codeNodes.length, equals(1));
      expect(codeNodes.first.language, equals('dart'));
    });

    test('isolates LaTeX block and inline math without mangling', () {
      const input = r'''
# Physics Notes

The famous mass-energy equivalence:

$$E = mc^2$$

And inline momentum $p = mv$ applies classically.
''';

      final ast = extractor.extract(input, filename: 'physics.md');

      expect(ast.registry.artifacts.length, equals(2));
      final mathBlock = ast.registry.artifacts.values
          .firstWhere((a) => a.type == ArtifactType.mathBlock);
      expect(mathBlock.rawContent, equals(r'$$E = mc^2$$'));

      final mathInline = ast.registry.artifacts.values
          .firstWhere((a) => a.type == ArtifactType.mathInline);
      expect(mathInline.rawContent, equals(r'$p = mv$'));
    });

    test('performs greedy line-wrap normalization on PDF column breaks', () {
      const input = '''
The MVP principle suggests that you
should focus on core features first
and avoid over-engineering.
''';

      final ast = extractor.extract(input);
      final paragraph = ast.nodes.whereType<ParagraphNode>().first;

      expect(
        paragraph.rawText,
        equals(
          'The MVP principle suggests that you should focus on core features first and avoid over-engineering.',
        ),
      );
    });

    test('unwraps line-end hyphens correctly', () {
      const input = '''
This is a standard imple-
mentation of the algorithm.
''';

      final ast = extractor.extract(input);
      final paragraph = ast.nodes.whereType<ParagraphNode>().first;

      expect(
        paragraph.rawText,
        equals('This is a standard implementation of the algorithm.'),
      );
    });

    test('identifies EBNF formal grammar productions', () {
      const input = '''
BreakStatement:
    break [Identifier] ;
''';

      final ast = extractor.extract(input, filename: 'jls.pdf');
      final grammarNodes = ast.nodes.whereType<GrammarProductionNode>().toList();

      expect(grammarNodes.length, equals(1));
      expect(grammarNodes.first.nonTerminal, equals('BreakStatement'));
      expect(grammarNodes.first.productionRule, contains('break [Identifier] ;'));
    });
  });
}
