import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/data/services/offline_card_builder.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_ir.dart';

void main() {
  group('Task 0.5: Strict LaTeX Formula Extraction Gating & Table Sanitization', () {
    const service = FormulaExtractionService.instance;
    const cardBuilder = OfflineCardBuilder();

    group('1. Cloze Blank Marker Rejection', () {
      final clozeFormulas = [
        'E = _____',
        r'F = m \cdot ___',
        'a^2 + b^2 = _____',
        'y = [...] + b',
        r'\text{cloze}(x) = 1',
        'T(n) = _____ + O(n)',
      ];

      for (final formula in clozeFormulas) {
        test('rejects cloze blank formula: "$formula"', () {
          expect(
            FormulaExtractionService.isValidLatexEquation(formula),
            isFalse,
            reason: 'isValidLatexEquation must reject formulas with cloze blanks',
          );
          expect(
            FormulaExtractionService.isFormula(formula),
            isFalse,
            reason: 'isFormula must reject formulas with cloze blanks',
          );
          expect(
            service.extractFormula(formula),
            isNull,
            reason: 'extractFormula must return null for cloze blank formulas',
          );
        });
      }
    });

    group('2. Unbalanced Bracket & Delimiter Rejection', () {
      final unbalanced = [
        r'\frac{a}{b',
        r'\int_{0}^{1} x dx [',
        '(a + b] = c',
        '{unclosed brace',
        'E = mc^2}',
        r'\left( \frac{a}{b} \right',
        r'x + \',
        'f(x) = (x + 1',
      ];

      for (final badLatex in unbalanced) {
        test('rejects unbalanced LaTeX expression: "$badLatex"', () {
          expect(
            FormulaExtractionService.isBalancedLatex(badLatex),
            isFalse,
            reason: 'isBalancedLatex must return false for unbalanced brackets',
          );
          expect(
            FormulaExtractionService.isValidLatexEquation(badLatex),
            isFalse,
            reason: 'isValidLatexEquation must return false for unbalanced brackets',
          );
        });
      }

      final balanced = [
        r'\frac{a}{b}',
        r'\int_{0}^{1} x dx',
        'E = mc^2',
        '(a + [b * {c}])',
        r'\left( \frac{a}{b} \right)',
        r'x + \\',
      ];

      for (final goodLatex in balanced) {
        test('accepts balanced LaTeX expression: "$goodLatex"', () {
          expect(
            FormulaExtractionService.isBalancedLatex(goodLatex),
            isTrue,
            reason: 'isBalancedLatex must return true for balanced brackets',
          );
        });
      }
    });

    group('3. Leading Binary Operators & Missing LHS Rejection', () {
      final leadingOperators = [
        '+ 5x = 10',
        '* 4 = 16',
        '/ 2 = x',
        '= mc^2',
        '^2 + 5 = 10',
        '- = 5',
        '- + 3',
        '+',
        '-',
        '=',
        '*',
        '/',
        '^',
        '= 42',
      ];

      for (final badOp in leadingOperators) {
        test('rejects leading operator or missing LHS: "$badOp"', () {
          expect(
            FormulaExtractionService.isValidLatexEquation(badOp),
            isFalse,
            reason: 'isValidLatexEquation must reject leading binary operators without an LHS',
          );
          expect(
            FormulaExtractionService.isFormula(badOp),
            isFalse,
            reason: 'isFormula must reject leading binary operators without an LHS',
          );
          expect(
            service.extractFormula(badOp),
            isNull,
            reason: 'extractFormula must return null for leading binary operators',
          );
        });
      }

      test('permits valid unary minus in genuine mathematical equations', () {
        const unaryMinus1 = r'- \frac{1}{2} g t^2';
        const unaryMinus2 = r'\nabla \times \mathbf{E} = -\frac{\partial \mathbf{B}}{\partial t}';
        expect(FormulaExtractionService.isValidLatexEquation(unaryMinus1), isTrue);
        expect(FormulaExtractionService.isValidLatexEquation(unaryMinus2), isTrue);
      });
    });

    group('4. High Prose Word Density Gating (> 40%)', () {
      final proseSentences = [
        'The formula for the kinetic energy of an object is E = 1/2 mv^2',
        'In this section we demonstrate that when a system is initialized x = y + z',
        'This mathematical equation governs the underlying software transaction mechanism',
        'According to the research team the relationship holds where a is mass and b is speed',
      ];

      for (final prose in proseSentences) {
        test('rejects high prose word density sentence: "$prose"', () {
          expect(
            FormulaExtractionService.hasHighProseWordDensity(prose),
            isTrue,
            reason: 'hasHighProseWordDensity must detect sentences with > 40% prose words',
          );
          expect(
            FormulaExtractionService.isValidLatexEquation(prose),
            isFalse,
            reason: 'isValidLatexEquation must reject candidates dominated by prose words',
          );
        });
      }

      final genuineMath = [
        'E = mc^2',
        'a^2 + b^2 = c^2',
        'C6H12O6 + 6O2 → 6CO2 + 6H2O + energy',
        'T(n) = 2T(n/2) + O(n)',
        'Rate = k [A]^m [B]^n',
        r'\text{Attention}(Q, K, V) = \text{softmax}\left(\frac{Q K^T}{\sqrt{d_k}}\right) V',
        r'\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}',
        r'H_D = \alpha \cdot (p - e A) + \beta m + e A_0',
      ];

      for (final math in genuineMath) {
        test('accepts genuine math with low prose word density: "$math"', () {
          expect(
            FormulaExtractionService.hasHighProseWordDensity(math),
            isFalse,
            reason: 'hasHighProseWordDensity must pass genuine mathematical formulas',
          );
          expect(
            FormulaExtractionService.isValidLatexEquation(math),
            isTrue,
            reason: 'isValidLatexEquation must accept genuine mathematical formulas',
          );
        });
      }
    });

    group('5. Document Preamble Stripping', () {
      test('strips standard LaTeX document preamble declarations cleanly', () {
        const rawPreambleDoc = r'''
\documentclass[12pt]{article}
\usepackage{amsmath}
\usepackage{amssymb}
\author{Albert Einstein}
\title{Zur Elektrodynamik bewegter Körper}
\date{1905}
\begin{document}
\maketitle
% Comment line
E = mc^2
\end{document}
''';
        final stripped = FormulaExtractionService.stripLatexPreamble(rawPreambleDoc);
        expect(stripped, equals('E = mc^2'));
        expect(FormulaExtractionService.isValidLatexEquation(stripped), isTrue);

        final formula = service.extractFormula(rawPreambleDoc);
        expect(formula, isNotNull);
        expect(formula!.latex, equals('E = mc^2'));
      });

      test('rejects documents containing only preamble declarations without body math', () {
        const onlyPreamble = r'''
\documentclass{article}
\usepackage{amsmath}
\author{Author Name}
\begin{document}
\maketitle
\end{document}
''';
        final stripped = FormulaExtractionService.stripLatexPreamble(onlyPreamble);
        expect(stripped, isEmpty);
        expect(FormulaExtractionService.isValidLatexEquation(onlyPreamble), isFalse);
        expect(service.extractFormula(onlyPreamble), isNull);
      });
    });

    group('6. Zero Formula-for-Formula Cards (Prevent Recursive Templates)', () {
      test('resolves specific heading or LHS and never generates "formula for this formula"', () {
        const passageWithGenericHeading = r'''
# Formula

$$
E = mc^2
$$
''';
        final cards = cardBuilder.buildCards(passageWithGenericHeading);
        for (final card in cards) {
          expect(
            card.front.toLowerCase(),
            isNot(contains('formula for this formula')),
            reason: 'Must never produce "What is the formula for this formula?"',
          );
          expect(
            card.front.toLowerCase(),
            isNot(contains('formula for formula')),
            reason: 'Must never produce "What is the formula for formula?"',
          );
          expect(
            card.front.toLowerCase(),
            isNot(contains('chemical equation for this reaction')),
            reason: 'Must never produce "What is the chemical equation for this reaction?"',
          );
        }

        // When heading is generic ("Formula"), the LHS identifier ("E") is resolved
        final formulaCard = cards.where((c) => c.type == OfflineCardType.formula).firstOrNull;
        if (formulaCard != null) {
          expect(formulaCard.front, equals('What is the formula for E?'));
        }
      });

      test('resolves specific heading when available', () {
        const passageWithSpecificHeading = r'''
# Mass-Energy Equivalence

$$
E = mc^2
$$
''';
        final cards = cardBuilder.buildCards(passageWithSpecificHeading);
        final formulaCard = cards.where((c) => c.type == OfflineCardType.formula).firstOrNull;
        expect(formulaCard, isNotNull);
        expect(formulaCard!.front, equals('What is the formula for Mass-Energy Equivalence?'));
        expect(formulaCard.back, contains('E = mc^2'));
      });

      test('suppresses card when equation has no LHS and all headings/context are generic', () {
        // Equation without LHS and generic block term/heading
        const mathBlock = MathBlock(
          latex: r'\int_0^\infty e^{-x} dx = 1',
          isDisplay: true,
          rawMathText: r'\int_0^\infty e^{-x} dx = 1',
          provenance: BlockProvenance(docId: 'doc1', page: 1, readingOrder: 1, sectionPath: ['Formula']),
        );

        const docIR = DocumentIR(
          docId: 'doc1',
          filename: 'test.md',
          blocks: [mathBlock],
        );

        final cards = cardBuilder.buildCardsFromIR(docIR);
        for (final card in cards) {
          expect(
            card.front.toLowerCase(),
            isNot(contains('formula for this formula')),
          );
          expect(
            card.front.toLowerCase(),
            isNot(contains('formula for formula')),
          );
        }
      });
    });

    group('7. Table Cell Pipe Escaping & Parsing', () {
      test('escapes unescaped pipes within LaTeX math in table cells', () {
        const rawCell = r'$|x| < 1$';
        final escaped = FormulaExtractionService.escapeTablePipes(rawCell);
        expect(escaped, equals(r'$\|x\| < 1$'));

        const conditionalProb = r'$P(A|B) = \frac{P(A \cap B)}{P(B)}$';
        final escapedProb = FormulaExtractionService.escapeTablePipes(conditionalProb);
        expect(escapedProb, equals(r'$P(A\|B) = \frac{P(A \cap B)}{P(B)}$'));
      });

      test('does not break Markdown table column counts when cells contain math with pipes', () {
        const markdownTable = r'''
| Function | Definition | Domain |
|---|---|---|
| Absolute Value | $|x|$ | $(-\infty, \infty)$ |
| Conditional Probability | $P(A|B)$ | $[0, 1]$ |
''';

        final cards = cardBuilder.buildCards(markdownTable);
        final tableCards = cards.where((c) => c.type == OfflineCardType.table).toList();
        expect(tableCards, isNotEmpty);

        for (final card in tableCards) {
          // Verify that back table row has 3 columns (separated by 4 unescaped pipes | col1 | col2 | col3 |)
          final unescapedPipes = RegExp(r'(?<!\\)\|').allMatches(card.back).length;
          expect(
            unescapedPipes,
            equals(4),
            reason: 'Table row with 3 columns must contain exactly 4 unescaped table delimiter pipes: "${card.back}"',
          );
        }
      });
    });
  });
}
