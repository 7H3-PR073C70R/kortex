import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/utils/bionic_text_formatter.dart';

void main() {
  group('BionicTextFormatter Test Suite', () {
    test('returns empty string when given empty or blank input', () {
      expect(BionicTextFormatter.format(''), equals(''));
      expect(BionicTextFormatter.format('   '), equals('   '));
    });

    test('bolds initial fixation letters of natural words', () {
      const input = 'Quantum Mechanics';
      final output = BionicTextFormatter.format(input);
      // 'Quantum' (7 chars) -> ceil(7 * 0.45) = 4 -> **Quan**tum
      // 'Mechanics' (9 chars) -> ceil(9 * 0.45) = 5 -> **Mecha**nics
      expect(output, contains('**Quan**tum'));
      expect(output, contains('**Mecha**nics'));
    });

    test('handles short words appropriately', () {
      const input = 'An atom is the base';
      final output = BionicTextFormatter.format(input);
      expect(output, contains('**A**n'));
      expect(output, contains('**at**om'));
      expect(output, contains('**i**s'));
      expect(output, contains('**t**he'));
    });

    test('preserves LaTeX math formulas without altering math syntax', () {
      const input = r'Calculate the energy when $E = mc^2$ and $$\Delta H = 0$$.';
      final output = BionicTextFormatter.format(input);
      expect(output, contains(r'$E = mc^2$'));
      expect(output, contains(r'$$\Delta H = 0$$'));
      expect(output, contains('**Calcu**late'));
    });

    test('skips formatting when text already has explicit bold markdown', () {
      const input = 'This is **already** highlighted.';
      final output = BionicTextFormatter.format(input);
      expect(output, equals(input));
    });
  });
}
