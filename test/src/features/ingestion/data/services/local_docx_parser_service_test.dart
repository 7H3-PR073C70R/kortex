import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_docx_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

void main() {
  const fixturesDir = 'test/fixtures/ingestion';

  /// Helper to create a valid synthetic DOCX byte buffer.
  Uint8List createSampleDocxBytes({
    required String bodyXml,
    Map<String, String>? relationships,
  }) {
    final archive = Archive();

    final docXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
            xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <w:body>
    $bodyXml
  </w:body>
</w:document>
''';
    final docBytes = utf8.encode(docXml);
    archive.addFile(ArchiveFile('word/document.xml', docBytes.length, docBytes));

    if (relationships != null && relationships.isNotEmpty) {
      final relsBuffer = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');
      for (final entry in relationships.entries) {
        relsBuffer.writeln('  <Relationship Id="${entry.key}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="${entry.value}"/>');
      }
      relsBuffer.writeln('</Relationships>');
      final relsBytes = utf8.encode(relsBuffer.toString());
      archive.addFile(ArchiveFile('word/_rels/document.xml.rels', relsBytes.length, relsBytes));
    }

    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  group('LocalDocxParserService Unit Tests', () {
    test('extracts document title and heading hierarchies (h1–h3)', () {
      final bytes = createSampleDocxBytes(
        bodyXml: '''
<w:p><w:pPr><w:pStyle w:val="Title"/></w:pPr><w:r><w:t>Biochemistry Handbook</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Chapter 1: Enzymes</w:t></w:r></w:p>
<w:p><w:r><w:t>Enzymes accelerate chemical reactions without being consumed.</w:t></w:r></w:p>
<w:p><w:pPr><w:pStyle w:val="Heading2"/></w:pPr><w:r><w:t>1.1 Catalytic Mechanism</w:t></w:r></w:p>
<w:p><w:r><w:t>Transition state stabilization lowers activation energy.</w:t></w:r></w:p>
''',
      );

      final extracted = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains('# Biochemistry Handbook'));
      expect(extracted, contains('# Chapter 1: Enzymes'));
      expect(extracted, contains('## 1.1 Catalytic Mechanism'));
      expect(extracted, contains('Enzymes accelerate chemical reactions'));
    });

    test('extracts OpenXML tables into Markdown tables with headers and divider', () {
      final bytes = createSampleDocxBytes(
        bodyXml: '''
<w:tbl>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Enzyme</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Substrate</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Km (mM)</w:t></w:r></w:p></w:tc>
  </w:tr>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Hexokinase</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Glucose</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>0.05</w:t></w:r></w:p></w:tc>
  </w:tr>
  <w:tr>
    <w:tc><w:p><w:r><w:t>Glucokinase</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>Glucose</w:t></w:r></w:p></w:tc>
    <w:tc><w:p><w:r><w:t>10.0</w:t></w:r></w:p></w:tc>
  </w:tr>
</w:tbl>
''',
      );

      final extracted = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains('| Enzyme | Substrate | Km (mM) |'));
      expect(extracted, contains('| --- | --- | --- |'));
      expect(extracted, contains('| Hexokinase | Glucose | 0.05 |'));
      expect(extracted, contains('| Glucokinase | Glucose | 10.0 |'));
    });

    test('converts OMML equations into LaTeX notation', () {
      final bytes = createSampleDocxBytes(
        bodyXml: '''
<w:p>
  <w:r><w:t>The kinetic velocity follows the Michaelis-Menten relation: </w:t></w:r>
  <m:oMath>
    <m:f>
      <m:num><m:r><m:t>Vmax * [S]</m:t></m:r></m:num>
      <m:den><m:r><m:t>Km + [S]</m:t></m:r></m:den>
    </m:f>
  </m:oMath>
</w:p>
''',
      );

      final extracted = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains(r'$\frac{Vmax * [S]}{Km + [S]}$'));
    });

    test('formats consecutive monospace paragraphs into fenced code blocks', () {
      final bytes = createSampleDocxBytes(
        bodyXml: '''
<w:p><w:pPr><w:pStyle w:val="Heading1"/></w:pPr><w:r><w:t>Rust Implementation</w:t></w:r></w:p>
<w:p><w:pPr><w:rPr><w:rFonts w:ascii="Consolas"/></w:rPr></w:pPr><w:r><w:t>fn calculate_km(vmax: f64) -&gt; f64 {</w:t></w:r></w:p>
<w:p><w:pPr><w:rPr><w:rFonts w:ascii="Consolas"/></w:rPr></w:pPr><w:r><w:t>    vmax / 2.0</w:t></w:r></w:p>
<w:p><w:pPr><w:rPr><w:rFonts w:ascii="Consolas"/></w:rPr></w:pPr><w:r><w:t>}</w:t></w:r></w:p>
<w:p><w:r><w:t>This function computes the half-maximal substrate velocity.</w:t></w:r></w:p>
''',
      );

      final extracted = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains('```'));
      expect(extracted, contains('fn calculate_km(vmax: f64) -> f64 {'));
      expect(extracted, contains('    vmax / 2.0'));
      expect(extracted, contains('}'));
    });

    test('extracts drawings with alt text and relationship image targets', () {
      final bytes = createSampleDocxBytes(
        relationships: {'rIdImage1': 'media/enzyme_kinetics_curve.png'},
        bodyXml: '''
<w:p>
  <w:r><w:t>Michaelis-Menten saturation curve diagram:</w:t></w:r>
  <w:drawing>
    <wp:docPr id="1" name="Figure 1" descr="Lineweaver-Burk double reciprocal plot"/>
    <a:graphic>
      <a:graphicData>
        <a:blip r:embed="rIdImage1"/>
      </a:graphicData>
    </a:graphic>
  </w:drawing>
</w:p>
''',
      );

      final extracted = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(extracted, contains('![Lineweaver-Burk double reciprocal plot](media/enzyme_kinetics_curve.png)'));
    });

    test('throws CorruptDocumentException on empty or invalid DOCX bytes', () {
      expect(
        () => LocalDocxParserService.extractTextFromBytesSync(Uint8List(0)),
        throwsA(isA<CorruptDocumentException>()),
      );

      expect(
        () => LocalDocxParserService.extractTextFromBytesSync(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<CorruptDocumentException>()),
      );
    });

    test('throws CorruptDocumentException on corrupt fixture corrupt_truncated_header.docx', () {
      final file = File('$fixturesDir/corrupt_truncated_header.docx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final report = ExtractionReport(filename: 'corrupt_truncated_header.docx', fileType: 'docx');

      expect(
        () => LocalDocxParserService.extractTextFromBytesSync(bytes, filename: 'corrupt_truncated_header.docx', report: report),
        throwsA(isA<CorruptDocumentException>()),
      );
      expect(report.isCorrupt, isTrue);
    });
  });

  group('LocalDocxParserService Real Corpus Fixtures', () {
    test('extracts organic_chemistry_reaction_mechanisms.docx with tables and rate laws', () {
      final file = File('$fixturesDir/organic_chemistry_reaction_mechanisms.docx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final text = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(text, contains('# Nucleophilic Substitution and Elimination Mechanisms'));
      expect(text, contains('1. Nucleophilic Aliphatic Substitution: SN1 vs SN2'));
      expect(text, contains('Rate = k_2 [Substrate][Nucleophile]'));
      expect(text, contains('Rate = k_1 [Substrate]'));
      expect(text, contains('| Parameter | SN1 Mechanism | SN2 Mechanism | E1 Elimination | E2 Elimination |'));
      expect(text, contains('| --- | --- | --- | --- | --- |'));
    });

    test('extracts neurobiology_action_potentials.docx with ion channel tables', () {
      final file = File('$fixturesDir/neurobiology_action_potentials.docx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final text = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(text, contains('Action Potential'));
      expect(text, contains('|'));
    });

    test('extracts tutorial_rust_memory_safety_lifetimes.docx with Rust code blocks', () {
      final file = File('$fixturesDir/tutorial_rust_memory_safety_lifetimes.docx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final text = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(text, contains('Rust Lifetime Annotations'));
      expect(text, contains('pub struct TokenBuffer'));
      expect(text, contains("pub raw_source: &'a str"));
      expect(text, contains('```'));
    });

    test('extracts contract_employment_non_disclosure.docx clauses accurately', () {
      final file = File('$fixturesDir/contract_employment_non_disclosure.docx');
      expect(file.existsSync(), isTrue);

      final bytes = file.readAsBytesSync();
      final text = LocalDocxParserService.extractTextFromBytesSync(bytes);

      expect(text, contains('NON-DISCLOSURE'));
    });

    test('preserves multilingual Unicode in Hindi and Russian DOCX fixtures', () {
      final hindiFile = File('$fixturesDir/doc_hindi_astrophysics_gravitation.docx');
      expect(hindiFile.existsSync(), isTrue);
      final hindiText = LocalDocxParserService.extractTextFromBytesSync(hindiFile.readAsBytesSync());
      expect(hindiText.isNotEmpty, isTrue);

      final russianFile = File('$fixturesDir/doc_russian_neuroscience_memory.docx');
      expect(russianFile.existsSync(), isTrue);
      final russianText = LocalDocxParserService.extractTextFromBytesSync(russianFile.readAsBytesSync());
      expect(russianText.isNotEmpty, isTrue);
    });
  });
}
