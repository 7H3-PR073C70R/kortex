import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/document_ast_extractor.dart';
import 'package:kortex/src/features/ingestion/data/services/synthesis/flashcard_synthesizer.dart';

void main() {
  const extractor = DocumentAstExtractor();
  late FlashcardSynthesizer synthesizer;

  setUp(() {
    synthesizer = FlashcardSynthesizer();
  });

  group('FlashcardSynthesizer - Layer 3', () {
    test('synthesizes causality question from because clause', () {
      const text = '''
# Biochemistry
Cells consume glucose because enzymes catalyze glycolysis.
''';

      final ast = extractor.extract(text, filename: 'bio.md');
      final cards = synthesizer.synthesize(ast);

      expect(cards.any((c) => c.type == CognitiveQuestionType.causality), isTrue);
      final causalityCard = cards.firstWhere(
        (c) => c.type == CognitiveQuestionType.causality,
      );
      expect(causalityCard.front, contains('Why do Cells consume'));
      expect(causalityCard.back, contains('because enzymes catalyze glycolysis'));
    });

    test('synthesizes mechanism question from by/using/via marker', () {
      const text = '''
# Mobile Architecture
Flutter compiles code by invoking the AOT compiler.
''';

      final ast = extractor.extract(text, filename: 'flutter.md');
      final cards = synthesizer.synthesize(ast);

      expect(cards.any((c) => c.type == CognitiveQuestionType.mechanism), isTrue);
      final mechanismCard = cards.firstWhere(
        (c) => c.type == CognitiveQuestionType.mechanism,
      );
      expect(mechanismCard.front, contains('How does Flutter compile'));
      expect(mechanismCard.back, contains('by invoking the AOT compiler'));
    });

    test('synthesizes state transition question from gerund method call', () {
      const text = '''
# Lifecycle
Calling dispose() cancels active timers and closes streams.
''';

      final ast = extractor.extract(text, filename: 'flutter.md');
      final cards = synthesizer.synthesize(ast);

      expect(cards.any((c) => c.type == CognitiveQuestionType.stateTransition), isTrue);
      final stateCard = cards.firstWhere(
        (c) => c.type == CognitiveQuestionType.stateTransition,
      );
      expect(stateCard.front, contains('What happens when dispose() is called?'));
      expect(stateCard.back, contains('Calling dispose() cancels active timers'));
    });

    test('relinks code block placeholders back to intact markdown', () {
      const text = '''
# Flutter State

Here is how you increment state:

```dart
class Counter {
  int count = 0;
  void increment() => count++;
}
```
''';

      final ast = extractor.extract(text, filename: 'flutter.md');
      final cards = synthesizer.synthesize(ast);

      final codeCard = cards.firstWhere((c) => c.type == CognitiveQuestionType.code);
      expect(codeCard.front, contains('Counter in dart'));
      expect(codeCard.back, contains('```dart'));
      expect(codeCard.back, contains('class Counter'));
    });

    test('filters out anaphoric pronouns and resolves using heading', () {
      const text = '''
# Glycolysis
It takes place in the cytoplasm because enzymes are present there.
''';

      final ast = extractor.extract(text, filename: 'bio.md');
      final cards = synthesizer.synthesize(ast);

      for (final card in cards) {
        expect(card.front.toLowerCase(), isNot(contains('it take place')));
        expect(card.front.toLowerCase(), isNot(contains('it consume')));
      }
    });
  });
}
