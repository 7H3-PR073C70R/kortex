import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

void main() {
  const builder = OfflineCardBuilder();

  group('Step 2: Code and Math Normalization Safety', () {
    test('preserves code blocks byte-for-byte including indentation, numeric output and divider lines', () {
      const expectedCode = '''
```python
def compute_metrics(values):
    # ==== Output Config ====
    total = 0
    for v in values:
        if v > 0:
            total += v
    
    # Check intermediate
    count = 42
    ====
    print(count)
    return total / count
```''';

      const input = '''
## Metric Calculation

Here is how to calculate metrics in the pipeline:

$expectedCode

This function handles non-zero inputs efficiently.
''';

      final cards = builder.buildCards(input);
      final codeCards = cards.where((c) => c.type == OfflineCardType.code).toList();

      expect(codeCards, isNotEmpty, reason: 'Must generate a code card');
      final card = codeCards.first;
      expect(card.back, equals(expectedCode), reason: 'Code back must equal code input byte-for-byte');
    });

    test('preserves ~~~ fenced code blocks byte-for-byte', () {
      const expectedCode = '''
~~~dart
class CounterService {
  int _count = 0;

  void increment() {
    _count++;
  }
}
~~~''';

      const input = '''
## State Management

$expectedCode
''';

      final cards = builder.buildCards(input);
      final codeCards = cards.where((c) => c.type == OfflineCardType.code).toList();

      expect(codeCards, isNotEmpty);
      expect(codeCards.first.back, equals(expectedCode));
    });

    test(r'preserves display math blocks byte-for-byte with $$', () {
      const expectedMath = r'''
$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}
$$''';

      const input = '''
## Gaussian Integral

The standard gaussian integral over the real line:

$expectedMath
''';

      final cards = builder.buildCards(input);
      final formulaCards = cards.where((c) => c.type == OfflineCardType.formula).toList();

      expect(formulaCards, isNotEmpty);
      expect(formulaCards.first.back, equals(expectedMath));
    });

    test('preserves LaTeX equation environments byte-for-byte', () {
      const expectedEquation = r'''
\begin{equation}
E = \frac{m c^2}{\sqrt{1 - \frac{v^2}{c^2}}}
\end{equation}''';

      const input = '''
## Relativistic Energy

Energy formula:

$expectedEquation
''';

      final cards = builder.buildCards(input);
      final formulaCards = cards.where((c) => c.type == OfflineCardType.formula).toList();

      expect(formulaCards, isNotEmpty);
      expect(formulaCards.first.back, equals(expectedEquation));
    });

    test('LocalPdfParserService.sanitizeExtractedPages does not delete numeric output or divider lines inside code', () {
      const codePage = '''
Chapter 1: Code Examples

```python
def output_check():
    # ==== Divider ====
    42
    100
```
''';

      final sanitized = LocalPdfParserService.sanitizeExtractedPages([codePage]);
      expect(sanitized, contains('# ==== Divider ===='));
      expect(sanitized, contains('    42'));
      expect(sanitized, contains('    100'));
    });
  });
}
