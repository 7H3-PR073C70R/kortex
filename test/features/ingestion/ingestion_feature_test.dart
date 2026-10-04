import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/domain/services/recursive_text_splitter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecursiveTextSplitter Unit Tests', () {
    test('splits long text into semantic chunks keeping headers and math formulas intact', () {
      const splitter = RecursiveTextSplitter(chunkSize: 100, chunkOverlap: 20);
      const text = '''
# Quantum Mechanics Overview

Equation 1: \$E = mc^2\$

The energy of a particle is directly proportional to its mass and the square of the speed of light in vacuum.

Equation 2: \$ihbar \frac{partial}{partial t}Psi = hat{H}Psi\$

The Schrödinger equation describes the wave function of a quantum-mechanical system over time.
''';

      final chunks = splitter.splitText(text: text);
      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.first.content, contains('Quantum Mechanics Overview'));
    });
  });
}
