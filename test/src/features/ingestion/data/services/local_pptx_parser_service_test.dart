import 'dart:convert';
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
  }) {
    final archive = Archive();

    for (var i = 0; i < slides.length; i++) {
      final slideNum = i + 1;
      final slide = slides[i];
      final title = slide['title'] as String?;
      final bullets = slide['bullets'] as List<String>? ?? [];

      final xmlBuffer = StringBuffer()
        ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
        ..writeln(
          '<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" '
          'xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">',
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

      xmlBuffer
        ..writeln('    </p:spTree>')
        ..writeln('  </p:cSld>')
        ..writeln('</p:sld>');

      final xmlBytes = utf8.encode(xmlBuffer.toString());
      archive.addFile(
        ArchiveFile('ppt/slides/slide$slideNum.xml', xmlBytes.length, xmlBytes),
      );
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

    test('gracefully handles empty bytes returning empty string', () async {
      final extracted = await pptxParser.extractText(Uint8List(0));
      expect(extracted, isEmpty);
    });
  });
}
