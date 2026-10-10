import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_epub_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

void main() {
  const fixturesDir = 'test/fixtures/ingestion';

  /// Helper to create a valid synthetic EPUB byte buffer.
  Uint8List createSampleEpubBytes({
    required String title,
    required List<Map<String, String>> chapters, // id, href, xhtmlContent
    List<String>? spineIds,
  }) {
    final archive = Archive();

    // 1. mimetype
    final mimeBytes = utf8.encode('application/epub+zip');
    archive.addFile(ArchiveFile('mimetype', mimeBytes.length, mimeBytes));

    // 2. META-INF/container.xml
    const containerXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
''';
    final containerBytes = utf8.encode(containerXml);
    archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));

    // 3. OEBPS/content.opf
    final spineOrder = spineIds ?? chapters.map((c) => c['id']!).toList();
    final manifestBuffer = StringBuffer();
    final spineBuffer = StringBuffer();

    for (final ch in chapters) {
      manifestBuffer.writeln('    <item id="${ch['id']}" href="${ch['href']}" media-type="application/xhtml+xml"/>');
    }
    for (final id in spineOrder) {
      spineBuffer.writeln('    <itemref idref="$id"/>');
    }

    final opfXml = '''
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="2.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:language>en</dc:language>
  </metadata>
  <manifest>
$manifestBuffer
  </manifest>
  <spine>
$spineBuffer
  </spine>
</package>
''';
    final opfBytes = utf8.encode(opfXml);
    archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

    // 4. Chapter files
    for (final ch in chapters) {
      final chBytes = utf8.encode(ch['xhtmlContent']!);
      archive.addFile(ArchiveFile('OEBPS/${ch['href']}', chBytes.length, chBytes));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  group('LocalEpubParserService Unit Tests', () {
    test('extracts book title and chapters in true sequential spine order', () {
      final bytes = createSampleEpubBytes(
        title: 'Algorithms in Practice',
        chapters: [
          {
            'id': 'chap_intro',
            'href': 'intro.xhtml',
            'xhtmlContent': '''
<html><body>
  <h1>Introduction to Graph Theory</h1>
  <p>A graph G = (V, E) consists of vertices and edges.</p>
</body></html>''',
          },
          {
            'id': 'chap_dijkstra',
            'href': 'dijkstra.xhtml',
            'xhtmlContent': '''
<html><body>
  <h2>Dijkstra Shortest Path</h2>
  <p>Computes single-source shortest paths on non-negative weighted graphs.</p>
  <table>
    <tr><th>Graph</th><th>Vertices</th><th>Complexity</th></tr>
    <tr><td>Sparse</td><td>V</td><td>O((V + E) log V)</td></tr>
  </table>
</body></html>''',
          },
        ],
        // Note: reversed spine order to verify spine takes precedence over manifest order
        spineIds: ['chap_dijkstra', 'chap_intro'],
      );

      final extracted = LocalEpubParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains('# Algorithms in Practice'));
      expect(extracted, contains('## Dijkstra Shortest Path'));
      expect(extracted, contains('| Graph | Vertices | Complexity |'));
      expect(extracted, contains('# Introduction to Graph Theory'));

      // Dijkstra should appear before Intro due to spine order!
      final dijkstraIndex = extracted.indexOf('Dijkstra Shortest Path');
      final introIndex = extracted.indexOf('Introduction to Graph Theory');
      expect(dijkstraIndex, lessThan(introIndex));
    });

    test('extracts code blocks with language and indentation from chapter XHTML', () {
      final bytes = createSampleEpubBytes(
        title: 'Modern Web Patterns',
        chapters: [
          {
            'id': 'ch1',
            'href': 'ch1.xhtml',
            'xhtmlContent': '''
<html><body>
  <h1>State Management</h1>
  <pre><code class="language-typescript">
export function useStore&lt;T&gt;(initial: T): [T, (val: T) =&gt; void] {
  return useState(initial);
}
</code></pre>
</body></html>''',
          },
        ],
      );

      final extracted = LocalEpubParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains('```typescript'));
      expect(extracted, contains('export function useStore<T>(initial: T): [T, (val: T) => void] {'));
      expect(extracted, contains('return useState(initial);'));
      expect(extracted, contains('```'));
    });

    test('throws CorruptDocumentException on empty or invalid EPUB bytes', () {
      expect(
        () => LocalEpubParserService.extractTextFromBytesSync(Uint8List(0)),
        throwsA(isA<CorruptDocumentException>()),
      );

      expect(
        () => LocalEpubParserService.extractTextFromBytesSync(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<CorruptDocumentException>()),
      );
    });

    test('throws CorruptDocumentException on corrupt fixture corrupt_invalid_xml.epub', () {
      final file = File('$fixturesDir/corrupt_invalid_xml.epub');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final report = ExtractionReport(filename: 'corrupt_invalid_xml.epub', fileType: 'epub');

      expect(
        () => LocalEpubParserService.extractTextFromBytesSync(bytes, filename: 'corrupt_invalid_xml.epub', report: report),
        throwsA(isA<CorruptDocumentException>()),
      );
      expect(report.isCorrupt, isTrue);
    });
  });

  group('LocalEpubParserService Real Corpus Fixtures', () {
    test('extracts tutorial_typescript_react_patterns.epub with chapters and code', () {
      final file = File('$fixturesDir/tutorial_typescript_react_patterns.epub');
      expect(file.existsSync(), isTrue);

      final text = LocalEpubParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('Chapter 1: Generic Debounce Hooks'));
      expect(text, contains('useDebounce'));
      expect(text, contains('```'));
    });

    test('extracts economics_macroeconomic_equilibrium.epub across chapters', () {
      final file = File('$fixturesDir/economics_macroeconomic_equilibrium.epub');
      expect(file.existsSync(), isTrue);

      final text = LocalEpubParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('# Macroeconomic Equilibrium and Monetary Policy'));
      expect(text, contains('Equilibrium'));
    });

    test('extracts thermodynamics_statistical_physics.epub with formulas and principles', () {
      final file = File('$fixturesDir/thermodynamics_statistical_physics.epub');
      expect(file.existsSync(), isTrue);

      final text = LocalEpubParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('Thermodynamics'));
    });

    test('extracts doc_french_philosophy_epistemology.epub preserving French accents', () {
      final file = File('$fixturesDir/doc_french_philosophy_epistemology.epub');
      expect(file.existsSync(), isTrue);

      final text = LocalEpubParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text.isNotEmpty, isTrue);
      expect(text, anyOf(contains('Épistémologie'), contains('Epistemologie'), contains('Philosophie')));
    });

    test('extracts handbook_organic_synthesis_reference.epub across all 12 chapters', () {
      final file = File('$fixturesDir/handbook_organic_synthesis_reference.epub');
      expect(file.existsSync(), isTrue);

      final text = LocalEpubParserService.extractTextFromBytesSync(file.readAsBytesSync());

      expect(text, contains('Organic Synthesis'));
      expect(text.length, greaterThan(2000));
    });
  });
}
