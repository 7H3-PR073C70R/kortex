import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_response_formatter.dart';

void main() {
  group('SyllabotResponseFormatter', () {
    test('formats parenthesized LaTeX formulas into standard dollar math delimiters', () {
      const input = r'''
1. Mechanics
A 2 kg block slides down a frictionless incline.
A) (1.0\ \text{m/s}^2)
B) (2.0\ \text{m/s}^2)
C) (3.0\ \text{m/s}^2)
D) (4.0\ \text{m/s}^2)
''';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'A) $1.0\ \text{m/s}^2$'));
      expect(result, contains(r'B) $2.0\ \text{m/s}^2$'));
      expect(result, contains(r'C) $3.0\ \text{m/s}^2$'));
      expect(result, contains(r'D) $4.0\ \text{m/s}^2$'));
      expect(result.contains(r'(1.0\ \text{m/s}^2)'), isFalse);
    });

    test('formats resistors and Greek symbols enclosed in parentheses', () {
      const input = r'Three resistors of (2\ \Omega), (3\ \Omega), and (6\ \Omega) are connected in series.';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'$2\ \Omega$'));
      expect(result, contains(r'$3\ \Omega$'));
      expect(result, contains(r'$6\ \Omega$'));
      expect(result.contains(r'(2\ \Omega)'), isFalse);
    });

    test('formats frequency and speed with units in parentheses', () {
      const input = r'A sound wave has a frequency of (500\ \text{Hz}) and a wavelength of (0.68\ \text{m}). Speed is (340\ \text{m/s}).';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'$500\ \text{Hz}$'));
      expect(result, contains(r'$0.68\ \text{m}$'));
      expect(result, contains(r'$340\ \text{m/s}$'));
    });

    test('converts bracketed LaTeX expressions to dollar delimiters', () {
      const input = r'The impedance is [2\ \Omega] and angular frequency is [50\ \text{rad/s}].';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'$2\ \Omega$'));
      expect(result, contains(r'$50\ \text{rad/s}$'));
    });

    test(r'converts LaTeX block and inline delimiters \[...\] and \(...\) to standard markdown', () {
      const input = r'Let \(x = 5\) and solve: \[E = mc^2\].';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'$x = 5$'));
      expect(result, contains(r'$$E = mc^2$$'));
      expect(result.contains(r'\('), isFalse);
      expect(result.contains(r'\['), isFalse);
    });

    test('normalizes accidental double backslashes from JSON encoding', () {
      const input = r'Resistor is (5\\ \\Omega) and velocity is (340\\ \\text{m/s}).';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'$5\ \Omega$'));
      expect(result, contains(r'$340\ \text{m/s}$'));
      expect(result.contains(r'\\'), isFalse);
    });

    test('strips reasoning tags and prompt artifacts cleanly', () {
      const input = '<think>Analyze Newton laws first.</think><|im_start|>assistant\nForces: F = ma.';
      final result = SyllabotResponseFormatter.format(input);
      expect(result.contains('think'), isFalse);
      expect(result.contains('<|im_start|>'), isFalse);
      expect(result, contains('Forces: F = ma.'));
    });

    test('decodes HTML entities so they do not leak as raw strings', () {
      const input = 'If A &lt; B &amp; B &gt; C, then &quot;valid&quot; and &#39;true&#39;.';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains('If A < B & B > C, then "valid" and \'true\'.'));
    });

    test('wraps bare numbers with LaTeX units outside math delimiters', () {
      const input = r'The wave travels at 340\ \text{m/s} with resistance of 10\ \Omega.';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains(r'$340\ \text{m/s}$'));
      expect(result, contains(r'$10\ \Omega$'));
    });

    test('preserves code blocks intact without wrapping their internal text in LaTeX', () {
      const input = r'''
Check this function:
```dart
final speed = 340; // \text{m/s} inside code
```
Outside: (340\ \text{m/s})
''';
      final result = SyllabotResponseFormatter.format(input);
      expect(result, contains('```dart\nfinal speed = 340; // \\text{m/s} inside code\n```'));
      expect(result, contains(r'Outside: $340\ \text{m/s}$'));
    });
  });
}
