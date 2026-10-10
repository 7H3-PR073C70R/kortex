import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_html_parser_service.dart';

void main() {
  const fixturesDir = 'test/fixtures/ingestion';

  group('LocalHtmlParserService Unit Tests', () {
    test('extracts heading hierarchies (h1 through h6)', () {
      const html = '''
<!DOCTYPE html>
<html>
<body>
  <h1>Main Title</h1>
  <p>Introduction paragraph.</p>
  <h2>Section 1</h2>
  <h3>Subsection 1.1</h3>
  <h4>Deep Topic</h4>
</body>
</html>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains('# Main Title'));
      expect(extracted, contains('## Section 1'));
      expect(extracted, contains('### Subsection 1.1'));
      expect(extracted, contains('#### Deep Topic'));
      expect(extracted, contains('Introduction paragraph.'));
    });

    test('extracts HTML tables into standard Markdown tables', () {
      const html = '''
<table>
  <tr><th>Element</th><th>Symbol</th><th>Atomic Number</th></tr>
  <tr><td>Hydrogen</td><td>H</td><td>1</td></tr>
  <tr><td>Helium</td><td>He</td><td>2</td></tr>
</table>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains('| Element | Symbol | Atomic Number |'));
      expect(extracted, contains('| --- | --- | --- |'));
      expect(extracted, contains('| Hydrogen | H | 1 |'));
      expect(extracted, contains('| Helium | He | 2 |'));
    });

    test('extracts pre and code elements preserving language and entities', () {
      const html = '''
<p>Here is the implementation in Dart:</p>
<pre><code class="language-dart">
Map&lt;String, int&gt; countTokens(List&lt;String&gt; words) {
  final map = &lt;String, int&gt;{};
  for (final w in words) {
    map[w] = (map[w] ?? 0) + 1;
  }
  return map;
}
</code></pre>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains('```dart'));
      expect(extracted, contains('Map<String, int> countTokens(List<String> words) {'));
      expect(extracted, contains('map[w] = (map[w] ?? 0) + 1;'));
      expect(extracted, contains('```'));
    });

    test('extracts MathJax script tags as LaTeX math blocks', () {
      const html = r'''
<p>The Euler identity is:</p>
<script type="math/tex; mode=display">e^{i\pi} + 1 = 0</script>
<p>where <script type="math/tex">i = \sqrt{-1}</script> is the imaginary unit.</p>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains(r'$$e^{i\pi} + 1 = 0$$'));
      expect(extracted, contains(r'$i = \sqrt{-1}$'));
    });

    test('extracts KaTeX and arithmatex math containers', () {
      const html = r'''
<p>Newtonian gravitation equation:</p>
<div class="arithmatex">
  \[ F = G \frac{m_1 m_2}{r^2} \]
</div>
<p>where <span class="arithmatex">\( G \)</span> is the gravitational constant.</p>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains(r'$$F = G \frac{m_1 m_2}{r^2}$$'));
      expect(extracted, contains(r'$G$'));
    });

    test('extracts figure elements with captions and image sources', () {
      const html = '''
<figure>
  <img src="https://cdn.example.com/cell_structure.png" alt="Cell Organelles">
  <figcaption>Figure 1: Eukaryotic cell diagram highlighting mitochondria and nucleus.</figcaption>
</figure>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains('![Figure 1: Eukaryotic cell diagram highlighting mitochondria and nucleus.](https://cdn.example.com/cell_structure.png)'));
      expect(extracted, contains('Figure 1: Eukaryotic cell diagram'));
    });

    test('resolves Greek, differential, and mathematical entities', () {
      const html = '''
<p>&nabla; &middot; E = &rho; / &epsilon;<sub>0</sub></p>
<p>&nabla; &times; B = &mu;<sub>0</sub> J + &mu;<sub>0</sub>&epsilon;<sub>0</sub> &part;E / &part;t</p>
<p>c = 299,792,458 m &middot; s<sup>-1</sup></p>
''';

      final extracted = LocalHtmlParserService.extractTextFromString(html);

      expect(extracted, contains(r'\nabla '));
      expect(extracted, contains(r'\rho '));
      expect(extracted, contains(r'\epsilon _{0}'));
      expect(extracted, contains(r'\mu _{0}'));
      expect(extracted, contains(r'\cdot '));
      expect(extracted, contains('^{-1}'));
    });

    test('gracefully handles empty bytes returning empty string', () {
      expect(LocalHtmlParserService.extractTextFromBytesSync(Uint8List(0)), isEmpty);
      expect(LocalHtmlParserService.extractTextFromString(''), isEmpty);
    });
  });

  group('LocalHtmlParserService Real Corpus Fixtures', () {
    test('extracts classical_electrodynamics_maxwells_equations.html', () {
      final file = File('$fixturesDir/classical_electrodynamics_maxwells_equations.html');
      expect(file.existsSync(), isTrue);

      final text = LocalHtmlParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('# Classical Electrodynamics and Maxwell Field Equations'));
      expect(text, contains("1. Differential Form of Maxwell's Equations"));
      expect(text, contains(r'\nabla '));
      expect(text, contains('| Constant | Symbol | Exact / Value | SI Units |'));
      expect(text, contains('| Speed of Light in Vacuum | c | 299,792,458 |'));
      expect(text, contains('Figure 1: Energy flux density Poynting vector'));
    });

    test('extracts astrophysics_black_holes_hawking.html', () {
      final file = File('$fixturesDir/astrophysics_black_holes_hawking.html');
      expect(file.existsSync(), isTrue);

      final text = LocalHtmlParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('Black Hole'));
    });

    test('extracts invoice_enterprise_cloud_billing_2026.html with tables', () {
      final file = File('$fixturesDir/invoice_enterprise_cloud_billing_2026.html');
      expect(file.existsSync(), isTrue);

      final text = LocalHtmlParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('INVOICE'));
      expect(text, contains('|'));
    });

    test('extracts tutorial_python_asyncio_architecture.html with Python code blocks', () {
      final file = File('$fixturesDir/tutorial_python_asyncio_architecture.html');
      expect(file.existsSync(), isTrue);

      final text = LocalHtmlParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('# Architecting Scalable AsyncIO Services in Python'));
      expect(text, contains('asyncio'));
      expect(text, contains('```'));
    });

    test('extracts cryptography_elliptic_curves.html', () {
      final file = File('$fixturesDir/cryptography_elliptic_curves.html');
      expect(file.existsSync(), isTrue);

      final text = LocalHtmlParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('Elliptic'));
    });

    test('preserves multilingual texts in Chinese and Yoruba HTML fixtures', () {
      final chineseFile = File('$fixturesDir/doc_chinese_quantum_computing.html');
      expect(chineseFile.existsSync(), isTrue);
      final chineseText = LocalHtmlParserService.extractTextFromBytesSync(chineseFile.readAsBytesSync());
      expect(chineseText.isNotEmpty, isTrue);

      final yorubaFile = File('$fixturesDir/doc_yoruba_traditional_medicine_botany.html');
      expect(yorubaFile.existsSync(), isTrue);
      final yorubaText = LocalHtmlParserService.extractTextFromBytesSync(yorubaFile.readAsBytesSync());
      expect(yorubaText.isNotEmpty, isTrue);
    });
  });
}
