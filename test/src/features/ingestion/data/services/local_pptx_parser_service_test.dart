import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pptx_parser_service.dart';

void main() {
  late LocalPptxParserService pptxParser;

  setUp(() {
    pptxParser = const LocalPptxParserService();
  });

  Uint8List createSamplePptxBytes({
    required List<Map<String, dynamic>> slides,
    List<int>? presentationOrder,
    Map<int, String>? speakerNotes,
    List<Map<String, dynamic>>? tables,
    List<Map<String, dynamic>>? pictures,
    List<String>? mathXmls,
  }) {
    final archive = Archive();

    // 1. If custom presentation order is specified, build presentation.xml & rels
    if (presentationOrder != null) {
      final presRelsBuffer = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

      final presBuffer = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..writeln('<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">')
        ..writeln('  <p:sldIdLst>');

      for (var idx = 0; idx < presentationOrder.length; idx++) {
        final slideNum = presentationOrder[idx];
        final rId = 'rId${idx + 1}';
        presRelsBuffer.writeln('  <Relationship Id="$rId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$slideNum.xml"/>');
        presBuffer.writeln('    <p:sldId id="${256 + idx}" r:id="$rId"/>');
      }

      presRelsBuffer.writeln('</Relationships>');
      presBuffer.writeln('  </p:sldIdLst></p:presentation>');

      final presBytes = utf8.encode(presBuffer.toString());
      archive.addFile(ArchiveFile('ppt/presentation.xml', presBytes.length, presBytes));

      final presRelsBytes = utf8.encode(presRelsBuffer.toString());
      archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presRelsBytes.length, presRelsBytes));
    }

    // 2. Build slides
    for (var i = 0; i < slides.length; i++) {
      final slideNum = i + 1;
      final slide = slides[i];
      final title = slide['title'] as String?;
      final bullets = slide['bullets'] as List<String>? ?? [];

      final xmlBuffer = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..writeln(
          '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" '
          'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
          'xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math">',
        )
        ..writeln('  <p:cSld>')
        ..writeln('    <p:spTree>');

      if (title != null) {
        xmlBuffer
          ..writeln('      <p:sp>')
          ..writeln(
            '        <p:nvSpPr><p:cNvPr id="1" name="Title"/><p:nvPr><p:ph type="title"/></p:nvPr></p:nvSpPr>',
          )
          ..writeln('        <p:txBody>')
          ..writeln('          <a:p><a:r><a:t>$title</a:t></a:r></a:p>')
          ..writeln('        </p:txBody>')
          ..writeln('      </p:sp>');
      }

      if (bullets.isNotEmpty) {
        xmlBuffer
          ..writeln('      <p:sp>')
          ..writeln(
            '        <p:nvSpPr><p:cNvPr id="2" name="Body"/><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>',
          )
          ..writeln('        <p:txBody>');
        for (final bullet in bullets) {
          xmlBuffer.writeln(
            '          <a:p><a:r><a:t>$bullet</a:t></a:r></a:p>',
          );
        }
        xmlBuffer
          ..writeln('        </p:txBody>')
          ..writeln('      </p:sp>');
      }

      // Add tables if provided on slide 1
      if (slideNum == 1 && tables != null && tables.isNotEmpty) {
        for (final tblData in tables) {
          final rows = tblData['rows'] as List<List<String>>;
          xmlBuffer
            ..writeln('      <p:graphicFrame>')
            ..writeln('        <a:graphic><a:graphicData><a:tbl>');
          for (final row in rows) {
            xmlBuffer.writeln('          <a:tr>');
            for (final cell in row) {
              xmlBuffer.writeln('            <a:tc><a:txBody><a:p><a:r><a:t>$cell</a:t></a:r></a:p></a:txBody></a:tc>');
            }
            xmlBuffer.writeln('          </a:tr>');
          }
          xmlBuffer
            ..writeln('        </a:tbl></a:graphicData></a:graphic>')
            ..writeln('      </p:graphicFrame>');
        }
      }

      // Add pictures if provided on slide 1
      if (slideNum == 1 && pictures != null && pictures.isNotEmpty) {
        for (final picData in pictures) {
          final alt = picData['alt'] as String;
          final rId = picData['rId'] as String;
          xmlBuffer
            ..writeln('      <p:pic>')
            ..writeln('        <p:nvPicPr><p:cNvPr id="10" name="Picture 1" descr="$alt"/></p:nvPicPr>')
            ..writeln('        <p:blipFill><a:blip r:embed="$rId"/></p:blipFill>')
            ..writeln('      </p:pic>');
        }
      }

      // Add formulas if provided on slide 1
      if (slideNum == 1 && mathXmls != null && mathXmls.isNotEmpty) {
        for (final mathXml in mathXmls) {
          xmlBuffer.writeln('      $mathXml');
        }
      }

      xmlBuffer
        ..writeln('    </p:spTree>')
        ..writeln('  </p:cSld>')
        ..writeln('</p:sld>');

      final xmlBytes = utf8.encode(xmlBuffer.toString());
      archive.addFile(
        ArchiveFile('ppt/slides/slide$slideNum.xml', xmlBytes.length, xmlBytes),
      );

      // Slide rels (for notes and pictures)
      final hasNotes = speakerNotes != null && speakerNotes.containsKey(slideNum);
      final hasPics = slideNum == 1 && pictures != null && pictures.isNotEmpty;
      if (hasNotes || hasPics) {
        final slideRelsBuffer = StringBuffer()
          ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
          ..writeln('<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">');

        if (hasNotes) {
          slideRelsBuffer.writeln('  <Relationship Id="rIdNotes$slideNum" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide$slideNum.xml"/>');
        }
        if (hasPics) {
          for (final pic in pictures) {
            final rId = pic['rId'] as String;
            final target = pic['target'] as String;
            slideRelsBuffer.writeln('  <Relationship Id="$rId" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="$target"/>');
          }
        }
        slideRelsBuffer.writeln('</Relationships>');

        final relsBytes = utf8.encode(slideRelsBuffer.toString());
        archive.addFile(
          ArchiveFile('ppt/slides/_rels/slide$slideNum.xml.rels', relsBytes.length, relsBytes),
        );
      }

      // Add notes slide XML
      if (hasNotes) {
        final notesText = speakerNotes[slideNum]!;
        final notesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:notes xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld><p:spTree>
    <p:sp>
      <p:nvSpPr><p:cNvPr id="1" name="Notes Body"/><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>
      <p:txBody><a:p><a:r><a:t>$notesText</a:t></a:r></a:p></p:txBody>
    </p:sp>
  </p:spTree></p:cSld>
</p:notes>''';
        final notesBytes = utf8.encode(notesXml);
        archive.addFile(
          ArchiveFile('ppt/notesSlides/notesSlide$slideNum.xml', notesBytes.length, notesBytes),
        );
      }
    }

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  group('LocalPptxParserService Test Suite', () {
    test(
      'extracts structured text and titles from sample PPTX presentation in isolate',
      () async {
        final sampleBytes = createSamplePptxBytes(
          slides: [
            {
              'title': 'Introduction to Photosynthesis',
              'bullets': [
                'Light-dependent reactions occur in the thylakoid membrane.',
                'Calvin cycle fixes carbon dioxide into G3P sugars in the stroma.',
              ],
            },
            {
              'title': 'Cellular Respiration Comparison',
              'bullets': [
                'Glycolysis occurs in the cytoplasm producing 2 net ATP.',
                'Oxidative phosphorylation produces the bulk of cellular ATP.',
              ],
            },
          ],
        );

        final extracted = await pptxParser.extractText(sampleBytes);

        expect(
          extracted,
          contains('## Slide 1: Introduction to Photosynthesis'),
        );
        expect(
          extracted,
          contains(
            '• Light-dependent reactions occur in the thylakoid membrane.',
          ),
        );
        expect(
          extracted,
          contains(
            '• Calvin cycle fixes carbon dioxide into G3P sugars in the stroma.',
          ),
        );
        expect(
          extracted,
          contains('## Slide 2: Cellular Respiration Comparison'),
        );
        expect(
          extracted,
          contains('• Glycolysis occurs in the cytoplasm producing 2 net ATP.'),
        );
        expect(
          extracted,
          contains(
            '• Oxidative phosphorylation produces the bulk of cellular ATP.',
          ),
        );
      },
    );

    test('respects presentation.xml sldIdLst slide ordering instead of filename sort', () async {
      final reorderedBytes = createSamplePptxBytes(
        slides: [
          {'title': 'Alpha Concept (Physically in slide1.xml)'},
          {'title': 'Beta Concept (Physically in slide2.xml)'},
          {'title': 'Gamma Concept (Physically in slide3.xml)'},
        ],
        // True presentation sequence puts slide 2 first, then slide 1, then slide 3
        presentationOrder: [2, 1, 3],
      );

      final extracted = await pptxParser.extractText(reorderedBytes);

      final lines = extracted.split('\n').where((l) => l.startsWith('## Slide')).toList();
      expect(lines.length, equals(3));
      expect(lines[0], equals('## Slide 1: Beta Concept (Physically in slide2.xml)'));
      expect(lines[1], equals('## Slide 2: Alpha Concept (Physically in slide1.xml)'));
      expect(lines[2], equals('## Slide 3: Gamma Concept (Physically in slide3.xml)'));
    });

    test('extracts DrawingML tables (<a:tbl>) into formatted Markdown tables', () async {
      final tableBytes = createSamplePptxBytes(
        slides: [
          {'title': 'Performance Metrics'},
        ],
        tables: [
          {
            'rows': [
              ['Architecture', 'Throughput (req/s)', 'P99 Latency (ms)'],
              ['Monolith', '1,200', '45.0'],
              ['Microservices', '8,500', '12.5'],
            ],
          },
        ],
      );

      final extracted = await pptxParser.extractText(tableBytes);

      expect(extracted, contains('| Architecture | Throughput (req/s) | P99 Latency (ms) |'));
      expect(extracted, contains('| --- | --- | --- |'));
      expect(extracted, contains('| Monolith | 1,200 | 45.0 |'));
      expect(extracted, contains('| Microservices | 8,500 | 12.5 |'));
    });

    test('extracts speaker notes from linked notesSlide relationships', () async {
      final notesBytes = createSamplePptxBytes(
        slides: [
          {
            'title': 'System Overview',
            'bullets': ['Core infrastructure components and high availability'],
          },
        ],
        speakerNotes: {
          1: 'Emphasize to the client that the multi-region cluster fails over automatically within 3 seconds.',
        },
      );

      final extracted = await pptxParser.extractText(notesBytes);

      expect(extracted, contains('### Speaker Notes:'));
      expect(
        extracted,
        contains('Emphasize to the client that the multi-region cluster fails over automatically within 3 seconds.'),
      );
    });

    test('extracts images with alt text descriptions and embed references', () async {
      final picBytes = createSamplePptxBytes(
        slides: [
          {'title': 'Transformer Architecture'},
        ],
        pictures: [
          {
            'alt': 'Detailed Transformer encoder-decoder multi-head attention workflow',
            'rId': 'rIdPic1',
            'target': '../media/transformer_arch.png',
          },
        ],
      );

      final extracted = await pptxParser.extractText(picBytes);

      expect(
        extracted,
        contains('![Detailed Transformer encoder-decoder multi-head attention workflow](ppt/media/transformer_arch.png)'),
      );
    });

    test('extracts OMML / DrawingML equations from slides', () async {
      final mathBytes = createSamplePptxBytes(
        slides: [
          {'title': 'Electrodynamics'},
        ],
        mathXmls: [
          '''
<p:sp><p:txBody><a:p><m:oMath>
            <m:f><m:num><m:r><m:t>1</m:t></m:r></m:num><m:den><m:r><m:t>2</m:t></m:r></m:den></m:f>
          </m:oMath></a:p></p:txBody></p:sp>''',
        ],
      );

      final extracted = await pptxParser.extractText(mathBytes);

      expect(extracted, contains(r'$\frac{1}{2}$'));
    });

    test('extracts real corpus PPTX fixtures successfully with high fidelity', () async {
      final fixtures = [
        'presentation_biochemistry_cellular_metabolism.pptx',
        'presentation_cloud_microservices_architecture.pptx',
        'presentation_machine_learning_transformers.pptx',
        'presentation_robotics_kinematics_dh_parameters.pptx',
      ];

      for (final fixture in fixtures) {
        final file = File('test/fixtures/ingestion/$fixture');
        expect(file.existsSync(), isTrue);

        final bytes = file.readAsBytesSync();
        final extracted = await pptxParser.extractText(bytes);

        expect(extracted, isNotEmpty, reason: '$fixture should extract non-empty text');
        expect(extracted, contains('## Slide 1'), reason: '$fixture should contain Slide 1 header');

        // Test synchronous extraction returns matching text
        final syncExtracted = LocalPptxParserService.extractTextFromBytesSync(bytes);
        expect(syncExtracted, equals(extracted));
      }
    });

    test('gracefully handles empty bytes returning empty string', () async {
      final extracted = await pptxParser.extractText(Uint8List(0));
      expect(extracted, isEmpty);
      expect(LocalPptxParserService.extractTextFromBytesSync(Uint8List(0)), isEmpty);
    });
  });
}
