import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/quiz/domain/logic/formula_aware_text_formatter.dart';

void main() {
  group('FormulaAwareTextFormatter', () {
    test(r'formats spaced chemical reaction into LaTeX \mathrm', () {
      const input = 'Cu(NO 3 ) 3 + NO + N 2 O 4 + H 2 O';
      final formatted = FormulaAwareTextFormatter.formatFormulaAware(input);
      expect(formatted, r'$\mathrm{Cu(NO_3)_3 + NO + N_2O_4 + H_2O}$');
    });

    test('formats option line with bullet and prefix', () {
      const input = '• A. Cu(NO 3 ) 2 + 2NO 2 + 2H 2 O';
      final formatted = FormulaAwareTextFormatter.formatFormulaAware(input);
      expect(formatted, r'• A. $\mathrm{Cu(NO_3)_2 + 2NO_2 + 2H_2O}$');
    });

    test('formats reaction with state symbols and arrow', () {
      const input = 'NaOH (aq) + HCl (aq) -> NaCl (aq) + H 2 O (l)';
      final formatted = FormulaAwareTextFormatter.formatFormulaAware(input);
      expect(formatted, contains(r'\rightarrow'));
      expect(formatted, contains(r'\text{(aq)}'));
      expect(formatted, contains(r'H_2O'));
    });

    test('formats single chemical compounds like H2O, CO2, Ca(OH)2', () {
      expect(FormulaAwareTextFormatter.formatFormulaAware('H2O'), r'$\mathrm{H_2O}$');
      expect(FormulaAwareTextFormatter.formatFormulaAware('CO2'), r'$\mathrm{CO_2}$');
      expect(FormulaAwareTextFormatter.formatFormulaAware('Ca(OH)2'), r'$\mathrm{Ca(OH)_2}$');
      expect(FormulaAwareTextFormatter.formatFormulaAware('NaCl'), r'$\mathrm{NaCl}$');
    });

    test('formats scientific notation and powers', () {
      expect(FormulaAwareTextFormatter.formatFormulaAware('3 x 10^8'), r'$3 \times 10^{8}$');
      expect(FormulaAwareTextFormatter.formatFormulaAware('2^x = 32'), r'$2^x = 32$');
    });

    test('formats numeric and algebraic fractions', () {
      expect(FormulaAwareTextFormatter.formatFormulaAware('B. 3/4'), r'B. $\frac{3}{4}$');
      expect(FormulaAwareTextFormatter.formatFormulaAware('x/2'), r'$\frac{x}{2}$');
    });

    test('wraps raw LaTeX command without delimiters', () {
      const input = r'\frac{1}{2}';
      final formatted = FormulaAwareTextFormatter.formatFormulaAware(input);
      expect(formatted, r'$\frac{1}{2}$');
    });

    test('does not alter plain English text', () {
      const input = 'is a neutralization reaction because it involves';
      final formatted = FormulaAwareTextFormatter.formatFormulaAware(input);
      expect(formatted, input);

      const input2 = 'None of the above';
      expect(FormulaAwareTextFormatter.formatFormulaAware(input2), input2);
    });

    test('preserves text already wrapped in LaTeX delimiters', () {
      const input = r'The value is $\sqrt{64}$';
      final formatted = FormulaAwareTextFormatter.formatFormulaAware(input);
      expect(formatted, input);
    });

    test('formats full flashcard prompt with multiple options correctly', () {
      const cardFront = '''
Copper metal will react with concentrated trioxonitrate (V) acid to give?

Options:
• A. Cu(NO 3 ) 3 + NO + N 2 O 4 + H 2 O
• B. Cu(NO 3 ) 2 + NO + H 2 O
• C. CuO + NO 2 + H 2 O
• D. Cu(NO 3 ) 2 + 2NO 2 + 2H 2 O''';

      final result = FormulaAwareTextFormatter.formatFormulaAware(cardFront);
      expect(result, contains(r'• A. $\mathrm{Cu(NO_3)_3 + NO + N_2O_4 + H_2O}$'));
      expect(result, contains(r'• B. $\mathrm{Cu(NO_3)_2 + NO + H_2O}$'));
      expect(result, contains(r'• C. $\mathrm{CuO + NO_2 + H_2O}$'));
      expect(result, contains(r'• D. $\mathrm{Cu(NO_3)_2 + 2NO_2 + 2H_2O}$'));
      expect(result, startsWith('Copper metal will react with concentrated trioxonitrate (V) acid to give?'));
    });
  });
}
