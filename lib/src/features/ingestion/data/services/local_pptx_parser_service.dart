import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:xml/xml.dart';

/// Service responsible for extracting structured text, slide titles, tables,
/// speaker notes, formulas, and image descriptions from `.pptx` presentations
/// completely offline.
class LocalPptxParserService {
  const LocalPptxParserService();

  /// Extracts structured text from PPTX binary bytes in a background isolate.
  Future<String> extractText(Uint8List bytes) async {
    if (bytes.isEmpty) return '';
    return compute(_parsePptxBytesInIsolate, bytes);
  }

  /// Extracts structured text from PPTX binary bytes synchronously.
  static String extractTextFromBytesSync(Uint8List bytes) {
    if (bytes.isEmpty) return '';
    return _parsePptxBytesInIsolate(bytes);
  }

  /// Parses PPTX bytes into a unified text string grouping slide titles, body bullet points,
  /// tables, equations, alt-text diagrams, and speaker notes.
  static String _parsePptxBytesInIsolate(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final orderedSlideFiles = _resolveOrderedSlideFiles(archive);
      if (orderedSlideFiles.isEmpty) return '';

      final buffer = StringBuffer();

      for (var slideIndex = 0; slideIndex < orderedSlideFiles.length; slideIndex++) {
        final slideFile = orderedSlideFiles[slideIndex];
        final slideNumber = slideIndex + 1;
        final slideContent = utf8.decode(
          slideFile.content as List<int>,
          allowMalformed: true,
        );

        // Find slide relationships if present
        final relsFile = _findSlideRelsFile(archive, slideFile.name);
        final rels = relsFile != null
            ? _parseRels(utf8.decode(relsFile.content as List<int>, allowMalformed: true))
            : const <String, String>{};

        // Find speaker notes if linked
        String? speakerNotes;
        final notesTarget = rels.entries
            .firstWhere(
              (e) => e.value.contains('notesSlide'),
              orElse: () => const MapEntry('', ''),
            )
            .value;
        if (notesTarget.isNotEmpty) {
          final resolvedNotesPath = _resolvePath(slideFile.name, notesTarget);
          final notesFile = archive.findFile(resolvedNotesPath);
          if (notesFile != null) {
            speakerNotes = _parseNotesXml(
              utf8.decode(notesFile.content as List<int>, allowMalformed: true),
            );
          }
        }

        final slideText = _parseSlideXml(
          slideContent,
          slideNumber,
          rels: rels,
          speakerNotes: speakerNotes,
        );

        if (slideText.trim().isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln('\n');
          buffer.write(slideText);
        }
      }

      return buffer.toString().trim();
    } catch (e) {
      if (kDebugMode) {
        print('[LocalPptxParserService] Error parsing PPTX: $e');
      }
      throw Exception('Failed to extract text from PPTX: $e');
    }
  }

  /// Resolves the true slide sequence from `ppt/presentation.xml` (`<p:sldIdLst>`),
  /// falling back to numeric slide order if presentation.xml or rels is absent.
  static List<ArchiveFile> _resolveOrderedSlideFiles(Archive archive) {
    final orderedFiles = <ArchiveFile>[];

    // 1. Try reading ppt/presentation.xml and ppt/_rels/presentation.xml.rels
    final presentationFile = archive.findFile('ppt/presentation.xml');
    final presentationRelsFile = archive.findFile('ppt/_rels/presentation.xml.rels');

    if (presentationFile != null && presentationRelsFile != null) {
      try {
        final presDoc = XmlDocument.parse(
          utf8.decode(presentationFile.content as List<int>, allowMalformed: true),
        );
        final relsDoc = XmlDocument.parse(
          utf8.decode(presentationRelsFile.content as List<int>, allowMalformed: true),
        );

        final idToTarget = <String, String>{};
        for (final rel in relsDoc.findAllElements('Relationship')) {
          final id = rel.getAttribute('Id');
          final target = rel.getAttribute('Target');
          if (id != null && target != null) {
            idToTarget[id] = target;
          }
        }

        for (final sldId in presDoc.findAllElements('p:sldId')) {
          final rId = sldId.getAttribute('r:id');
          if (rId != null && idToTarget.containsKey(rId)) {
            final target = idToTarget[rId]!;
            final resolvedPath = _resolvePath('ppt/presentation.xml', target);
            final slideFile = archive.findFile(resolvedPath);
            if (slideFile != null && !orderedFiles.contains(slideFile)) {
              orderedFiles.add(slideFile);
            }
          }
        }
      } on Object catch (_) {
        // Fall back to numeric sort on error
      }
    }

    if (orderedFiles.isNotEmpty) {
      return orderedFiles;
    }

    // 2. Fallback: Collect all ppt/slides/slideN.xml and sort numerically
    final slideEntries = <int, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile &&
          file.name.startsWith('ppt/slides/slide') &&
          file.name.endsWith('.xml')) {
        final match = RegExp(r'ppt/slides/slide(\d+)\.xml').firstMatch(file.name);
        if (match != null) {
          final slideNumber = int.tryParse(match.group(1)!) ?? 0;
          slideEntries[slideNumber] = file;
        }
      }
    }

    final sortedKeys = slideEntries.keys.toList()..sort();
    return sortedKeys.map((k) => slideEntries[k]!).toList();
  }

  /// Parses relationships from an OpenXML `.rels` file.
  static Map<String, String> _parseRels(String relsXml) {
    final result = <String, String>{};
    try {
      final doc = XmlDocument.parse(relsXml);
      for (final rel in doc.findAllElements('Relationship')) {
        final id = rel.getAttribute('Id');
        final target = rel.getAttribute('Target');
        if (id != null && target != null) {
          result[id] = target;
        }
      }
    } on Object catch (_) {}
    return result;
  }

  /// Finds the relationship file corresponding to [slidePath].
  static ArchiveFile? _findSlideRelsFile(Archive archive, String slidePath) {
    final parts = slidePath.split('/');
    final filename = parts.removeLast();
    final relsPath = '${parts.join('/')}/_rels/$filename.rels';
    return archive.findFile(relsPath);
  }

  /// Resolves relative OpenXML paths (e.g. `../notesSlides/notesSlide1.xml`).
  static String _resolvePath(String basePath, String target) {
    if (target.startsWith('/')) return target.substring(1);
    final baseDirParts = basePath.split('/')..removeLast();
    final targetParts = target.split('/');
    for (final part in targetParts) {
      if (part == '..') {
        if (baseDirParts.isNotEmpty) baseDirParts.removeLast();
      } else if (part != '.') {
        baseDirParts.add(part);
      }
    }
    return baseDirParts.join('/');
  }

  /// Parses a single slide XML document extracting shapes, titles, body paragraphs,
  /// tables, alt-text images, and math formulas.
  static String _parseSlideXml(
    String xmlContent,
    int slideNumber, {
    Map<String, String> rels = const {},
    String? speakerNotes,
  }) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final paragraphs = <String>[];
      String? slideTitle;

      // 1. Title and Shape Extraction
      final shapes = document.findAllElements('p:sp');
      for (final shape in shapes) {
        final ph = shape.findAllElements('p:ph').firstOrNull;
        final phType = ph?.getAttribute('type');
        final isTitleShape = phType == 'title' || phType == 'ctrTitle';

        final shapeParagraphs = <String>[];
        for (final p in shape.findAllElements('a:p')) {
          final pTextBuffer = StringBuffer();
          for (final t in p.findAllElements('a:t')) {
            pTextBuffer.write(t.innerText);
          }
          final pText = pTextBuffer.toString().trim();
          if (pText.isNotEmpty) {
            shapeParagraphs.add(pText);
          }
        }

        if (isTitleShape && shapeParagraphs.isNotEmpty) {
          slideTitle = shapeParagraphs.join(' - ');
        } else if (shapeParagraphs.isNotEmpty) {
          paragraphs.addAll(shapeParagraphs);
        }
      }

      // Fallback: If no explicit title shape found, check the first text element
      if (slideTitle == null &&
          paragraphs.isNotEmpty &&
          paragraphs.first.length < 80 &&
          !paragraphs.first.startsWith('|')) {
        slideTitle = paragraphs.removeAt(0);
      }

      // 2. Tables (<a:tbl>)
      final tableMarkdownBlocks = <String>[];
      for (final tbl in document.findAllElements('a:tbl')) {
        final rows = <List<String>>[];
        for (final tr in tbl.findAllElements('a:tr')) {
          final row = <String>[];
          for (final tc in tr.findAllElements('a:tc')) {
            final cellText = tc
                .findAllElements('a:t')
                .map((t) => t.innerText.trim())
                .where((t) => t.isNotEmpty)
                .join(' ');
            row.add(cellText);
          }
          if (row.isNotEmpty) rows.add(row);
        }

        if (rows.isNotEmpty) {
          final maxCols = rows.map((r) => r.length).reduce(math.max);
          if (maxCols > 0) {
            final tableBuffer = StringBuffer();
            final headers = rows.first;
            while (headers.length < maxCols) {
              headers.add('');
            }
            tableBuffer
              ..writeln('| ${headers.join(' | ')} |')
              ..writeln('| ${List.filled(maxCols, '---').join(' | ')} |');
            for (var r = 1; r < rows.length; r++) {
              final row = rows[r];
              while (row.length < maxCols) {
                row.add('');
              }
              tableBuffer.writeln('| ${row.join(' | ')} |');
            }
            tableMarkdownBlocks.add(tableBuffer.toString().trim());
          }
        }
      }

      // 3. Pictures with Alt Text (<p:pic>)
      final imageCaptions = <String>[];
      for (final pic in document.findAllElements('p:pic')) {
        final cNvPr = pic.findAllElements('p:cNvPr').firstOrNull;
        final descr = cNvPr?.getAttribute('descr');
        final title = cNvPr?.getAttribute('title');
        final name = cNvPr?.getAttribute('name');
        final alt = (descr?.trim().isNotEmpty == true)
            ? descr!.trim()
            : (title?.trim().isNotEmpty == true)
                ? title!.trim()
                : (name != null && !name.startsWith('Picture'))
                    ? name.trim()
                    : null;

        final blip = pic.findAllElements('a:blip').firstOrNull;
        final embedId = blip?.getAttribute('r:embed');
        String? imagePath;
        if (embedId != null && rels.containsKey(embedId)) {
          imagePath = _resolvePath('ppt/slides/slide$slideNumber.xml', rels[embedId]!);
        }

        if (alt != null || imagePath != null) {
          if (imagePath != null) {
            imageCaptions.add('![${alt ?? 'Slide $slideNumber Diagram'}]($imagePath)');
          } else {
            imageCaptions.add('[Figure: $alt]');
          }
        }
      }

      // 4. DrawingML / OMML Equations (<a14:m>, <m:oMath>, <m:oMathPara>)
      final mathFormulas = <String>[];
      final mathElements = document.findAllElements('a14:m').toList()
        ..addAll(document.findAllElements('m:oMath'))
        ..addAll(document.findAllElements('m:oMathPara'));
      for (final m in mathElements) {
        final latex = FormulaExtractionService.convertOmmlToLatex(m.toXmlString());
        if (latex.isNotEmpty) {
          mathFormulas.add('\$$latex\$');
        }
      }

      // Construct Slide Markdown representation
      final slideBuffer = StringBuffer()
        ..writeln('## Slide $slideNumber${slideTitle != null ? ': $slideTitle' : ''}');

      for (final p in paragraphs) {
        if (p.startsWith('|') && p.endsWith('|')) {
          slideBuffer.writeln(p);
        } else {
          slideBuffer.writeln('• $p');
        }
      }

      for (final tbl in tableMarkdownBlocks) {
        slideBuffer.writeln('\n$tbl');
      }

      for (final img in imageCaptions) {
        slideBuffer.writeln('\n$img');
      }

      for (final formula in mathFormulas) {
        slideBuffer.writeln('\n$formula');
      }

      if (speakerNotes != null && speakerNotes.trim().isNotEmpty) {
        slideBuffer
          ..writeln('\n### Speaker Notes:')
          ..writeln(speakerNotes.trim());
      }

      return slideBuffer.toString().trim();
    } on Object catch (_) {
      return '';
    }
  }

  /// Parses speaker notes XML extracting body text paragraphs.
  static String? _parseNotesXml(String notesXml) {
    try {
      final doc = XmlDocument.parse(notesXml);
      final bodyShapes = doc.findAllElements('p:sp').where((sp) {
        final ph = sp.findAllElements('p:ph').firstOrNull;
        final type = ph?.getAttribute('type');
        return type == 'body' || (type != 'sldNum' && type != 'dt' && type != 'ftr');
      });

      final notes = <String>[];
      for (final sp in bodyShapes) {
        for (final p in sp.findAllElements('a:p')) {
          final text = p.findAllElements('a:t').map((t) => t.innerText).join().trim();
          if (text.isNotEmpty) {
            notes.add(text);
          }
        }
      }
      return notes.isNotEmpty ? notes.join('\n') : null;
    } on Object catch (_) {
      return null;
    }
  }
}
