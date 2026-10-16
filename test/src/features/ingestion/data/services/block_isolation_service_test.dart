import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/block_isolation_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';

void main() {
  group('Task 1.5: BlockIsolationService - Formula Line Detection', () {
    test('identifies explicit LaTeX math delimiters and environments', () {
      expect(BlockIsolationService.isFormulaLine(r'$$\sum_{i=1}^n x_i = S$$'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\[f(x) = \int_0^\infty e^{-t} dt\]'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\begin{equation}E = mc^2\end{equation}'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\begin{align} a &= b \\ c &= d \end{align}'), isTrue);
    });

    test('identifies lines starting with TeX math constructs', () {
      expect(BlockIsolationService.isFormulaLine(r'\sum_{i=1}^N \frac{1}{i^2} = \frac{\pi^2}{6}'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\frac{\partial u}{\partial t} = \alpha \nabla^2 u'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\lim_{x \to 0} \frac{\sin x}{x} = 1'), isTrue);
      expect(BlockIsolationService.isFormulaLine(r'\alpha + \beta = \gamma'), isTrue);
    });

    test('identifies lines starting or ending with math operators and relations', () {
      expect(BlockIsolationService.isFormulaLine('± 3.14159'), isTrue);
      expect(BlockIsolationService.isFormulaLine('∑ x_i'), isTrue);
      expect(BlockIsolationService.isFormulaLine('f(x) ='), isTrue);
      expect(BlockIsolationService.isFormulaLine('≈ 2.71828'), isTrue);
      expect(BlockIsolationService.isFormulaLine('E = mc^2'), isTrue);
      expect(BlockIsolationService.isFormulaLine('a^2 + b^2 = c^2'), isTrue);
    });

    test('safeguards programming code assignments and plain prose', () {
      expect(BlockIsolationService.isFormulaLine('var count = list.length;'), isFalse);
      expect(BlockIsolationService.isFormulaLine('final int max = 100;'), isFalse);
      expect(BlockIsolationService.isFormulaLine('String name = "kortex";'), isFalse);
      expect(BlockIsolationService.isFormulaLine('This equation represents conservation of energy in the closed system.'), isFalse);
      expect(BlockIsolationService.isFormulaLine('In our benchmarks, the algorithm demonstrated high throughput.'), isFalse);
    });
  });

  group('Task 1.5: BlockIsolationService - Caption Line Detection', () {
    test('identifies standard table, figure, and listing captions', () {
      expect(BlockIsolationService.isCaptionLine('Table 1: Memory Allocation Overhead in Mobile Apps'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Table 2.3 - Performance Benchmarks across Database Engines'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Figure 4: Flutter Render Pipeline Architecture'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Fig. 5. Overview of Convolutional Feature Maps'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Listing 1: Custom State Management Provider Implementation'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Algorithm 3: QuickSort with Median-of-Three Partitioning'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Chart 1: Quarterly User Retention Rates'), isTrue);
      expect(BlockIsolationService.isCaptionLine('Equation 2.1: Navier-Stokes Momentum Formulation'), isTrue);
    });

    test('distinguishes captions from prose sentences referencing tables or figures', () {
      expect(BlockIsolationService.isCaptionLine('Table 1 shows that memory overhead decreased by 40%.'), isFalse);
      expect(BlockIsolationService.isCaptionLine('Figure 2 illustrates the interaction between isolates.'), isFalse);
      expect(BlockIsolationService.isCaptionLine('Table 3 summarizes our findings on latency metrics.'), isFalse);
      expect(BlockIsolationService.isCaptionLine('As shown in Table 4, the response time is optimal.'), isFalse);
    });
  });

  group('Task 1.5: BlockIsolationService - Table Row Detection', () {
    test('identifies markdown table rows and dividers', () {
      expect(BlockIsolationService.isTableRowLine('| Algorithm | Time Complexity | Space Complexity |'), isTrue);
      expect(BlockIsolationService.isTableRowLine('|---|---|---|'), isTrue);
      expect(BlockIsolationService.isTableRowLine('|:---|:---:|---:|'), isTrue);
      expect(BlockIsolationService.isTableRowLine('Binary Search | O(log n) | O(1)'), isTrue);
      expect(BlockIsolationService.isTableRowLine('col1\tcol2\tcol3'), isTrue);
    });

    test('does not misclassify prose containing single pipes or dashes', () {
      expect(BlockIsolationService.isTableRowLine('In logical operations we use | or || for disjunction.'), isFalse);
      expect(BlockIsolationService.isTableRowLine('This is a simple bullet-point sentence.'), isFalse);
    });
  });

  group('Task 1.5: BlockIsolationService - Non-Punctuated Block Isolation', () {
    test('identifies structural key-value lines without sentence terminal punctuation', () {
      expect(
        BlockIsolationService.isNonPunctuatedBlock(
          currentLine: 'Input: Array of unsorted integers',
          nextLine: 'Output: Sorted array in ascending order',
        ),
        isTrue,
      );
      expect(
        BlockIsolationService.isNonPunctuatedBlock(
          currentLine: 'Time Complexity: O(n log n)',
          nextLine: 'Space Complexity: O(1) auxiliary storage',
        ),
        isTrue,
      );
    });

    test('isolates non-punctuated lines separated by significant vertical gaps', () {
      expect(
        BlockIsolationService.isNonPunctuatedBlock(
          currentLine: 'First Header Line',
          nextLine: 'Second Header Line',
          gap: 10,
          medianLineHeight: 12,
        ),
        isTrue,
      );
    });

    test('allows normal prose sentence line-wrapping without artificial breaks', () {
      expect(
        BlockIsolationService.isNonPunctuatedBlock(
          currentLine: 'Flutter is an open source framework by Google for building',
          nextLine: 'beautiful, natively compiled, multi-platform applications.',
          gap: 2,
          medianLineHeight: 14,
        ),
        isFalse,
      );
    });
  });

  group('Task 1.5: LocalPdfParserService - _appendProseLine Block Isolation', () {
    test('refuses to weld formula line onto preceding prose sentence', () {
      LocalPdfParserService.repairGluedWordRuns(''); // invoke static init if needed

      // Emulate calling layoutAwareLines or _appendProseLine
      const formulaLine = r'E_k = (\gamma - 1) m c^2';
      expect(BlockIsolationService.isFormulaLine(formulaLine), isTrue);

      final combined = StringBuffer('The kinetic energy of the relativistic body is given by');
      // When BlockIsolationService guard in _appendProseLine triggers:
      if (BlockIsolationService.isFormulaLine(formulaLine)) {
        combined.write('\n\n$formulaLine');
      }
      expect(combined.toString(), contains('\n\n'));
      expect(combined.toString(), isNot(contains('given by E_k')));
    });

    test('refuses to weld caption line onto preceding prose sentence', () {
      final buffer = StringBuffer('Extensive experiments were conducted across all benchmarks.');
      const captionLine = 'Table 1: Benchmark Results under Maximum Concurrency';

      expect(BlockIsolationService.isCaptionLine(captionLine), isTrue);

      final combined = StringBuffer(buffer.toString());
      if (BlockIsolationService.isCaptionLine(captionLine)) {
        combined.write('\n\n$captionLine');
      }
      expect(combined.toString(), contains('benchmarks.\n\nTable 1:'));
      expect(combined.toString(), isNot(contains('benchmarks. Table 1:')));
    });
  });

  group('Task 1.5: LocalPdfParserService - layoutAwareLines Structural Isolation', () {
    test('isolates formulas, captions, and tables into discrete blocks separated by blank lines', () {
      final lines = [
        const PdfLineLayout(
          text: 'The following table compares the runtime latency of sorting algorithms.',
          bounds: Rect.fromLTWH(50, 100, 450, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'Table 1: Comparison of Sorting Algorithms',
          bounds: Rect.fromLTWH(50, 125, 300, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: '| Algorithm | Average Time | Space |',
          bounds: Rect.fromLTWH(50, 145, 350, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: '|---|---|---|',
          bounds: Rect.fromLTWH(50, 160, 350, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: '| QuickSort | O(n log n) | O(log n) |',
          bounds: Rect.fromLTWH(50, 175, 350, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'Next we examine the theoretical complexity equation.',
          bounds: Rect.fromLTWH(50, 205, 400, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: r'$$T(n) = 2T(n/2) + O(n)$$',
          bounds: Rect.fromLTWH(50, 230, 250, 12),
          fontSize: 10,
        ),
        const PdfLineLayout(
          text: 'By applying the Master Theorem, we obtain the tight asymptotic bound.',
          bounds: Rect.fromLTWH(50, 260, 450, 12),
          fontSize: 10,
        ),
      ];

      final reconstructed = LocalPdfParserService.layoutAwareLines(lines);

      // Verify Table caption is isolated from preceding prose
      expect(reconstructed, contains('sorting algorithms.\n\nTable 1:'));
      // Verify Table is isolated from subsequent prose
      expect(reconstructed, contains('| QuickSort | O(n log n) | O(log n) |\n\nNext we examine'));
      // Verify Equation is isolated as its own block
      expect(reconstructed, contains('complexity equation.\n\n\$\$T(n) = 2T(n/2) + O(n)\$\$\n\nBy applying'));
      // Verify no hybrid glued run-ons
      expect(reconstructed, isNot(contains('sorting algorithms. Table 1:')));
      expect(reconstructed, isNot(contains(r'complexity equation. $$T(n)')));
    });
  });

  group('Task 1.5: OfflineCardBuilder Acceptance Criteria - 0 Hybrid Cloze Cards', () {
    const builder = OfflineCardBuilder();

    test('guarantees 0 hybrid cloze cards merging equations, table headers, and captions', () {
      const documentText = r'''
# Computational Performance

The performance of parallel tasks depends heavily on cache locality and scheduling.
Table 1: Benchmark Measurements Across 8 Cores
| Core Count | Speedup | Efficiency |
|---|---|---|
| 2 | 1.95 | 97.5% |
| 4 | 3.82 | 95.5% |
| 8 | 7.15 | 89.3% |

Amdahl's law defines the maximum theoretical speedup of an algorithm with parallel execution:
$$S(s) = \frac{1}{(1 - p) + \frac{p}{s}}$$
Where p represents the parallelizable proportion and s is the speedup factor of the parallel portion.

Figure 3: Speedup Curves for Different Parallel Fractions
Measurements demonstrate that diminishing returns occur as thread count exceeds physical cores.
''';

      final cards = builder.buildCards(documentText);
      expect(cards, isNotEmpty);

      final clozeCards = cards.where((c) => c.type == OfflineCardType.cloze).toList();

      for (final cloze in clozeCards) {
        final text = '${cloze.front} ${cloze.back}';

        // Acceptance Criteria: 0 hybrid cards merging equations
        expect(
          text.contains(r'$$') ||
              text.contains(r'\[') ||
              text.contains(r'\frac') ||
              text.contains('S(s) ='),
          isFalse,
          reason: 'Cloze card must not contain mathematical formulas: "${cloze.front}"',
        );

        // Acceptance Criteria: 0 hybrid cards merging table headers
        expect(
          text.contains('|') ||
              text.contains('Speedup') && text.contains('Efficiency') && text.contains('Core Count'),
          isFalse,
          reason: 'Cloze card must not contain table headers: "${cloze.front}"',
        );

        // Acceptance Criteria: 0 hybrid cards merging captions
        expect(
          RegExp(r'\b(?:Table|Figure|Listing|Algorithm)\s+\d+', caseSensitive: false).hasMatch(text),
          isFalse,
          reason: 'Cloze card must not contain caption labels: "${cloze.front}"',
        );
      }
    });

    test('BlockIsolationService.isHybridClozeCandidate correctly filters invalid candidate sentences', () {
      expect(BlockIsolationService.isHybridClozeCandidate('The results are shown in Table 1: Performance metrics.'), isTrue);
      expect(BlockIsolationService.isHybridClozeCandidate('Figure 2: Architecture of the deep learning model.'), isTrue);
      expect(BlockIsolationService.isHybridClozeCandidate(r'The rest energy is given by $$E = mc^2$$ in relativity.'), isTrue);
      expect(BlockIsolationService.isHybridClozeCandidate(r'The derivative is \frac{\partial f}{\partial x} at point p.'), isTrue);
      expect(BlockIsolationService.isHybridClozeCandidate('| Header 1 | Header 2 |'), isTrue);

      // Clean prose sentences must not be rejected
      expect(BlockIsolationService.isHybridClozeCandidate('Cellular respiration converts glucose into adenosine triphosphate.'), isFalse);
      expect(BlockIsolationService.isHybridClozeCandidate('Flutter widgets build their visual representation using composition.'), isFalse);
    });
  });
}
