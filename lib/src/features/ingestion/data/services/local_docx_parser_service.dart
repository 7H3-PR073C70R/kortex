import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:kortex/src/features/ingestion/data/services/formula_extraction_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

/// Native Microsoft Word DOCX parser service.
///
/// Parses OpenXML packages (`word/document.xml`, `word/_rels/document.xml.rels`)
/// into structured Markdown text preserving:
/// - Document body hierarchy (Title, Heading 1–6)
/// - DrawingML and OMML mathematical equations (`<m:oMath>`, `<m:oMathPara>`)
/// - Tables (`<w:tbl>`) converted to standard Markdown tables
/// - Monospace code blocks (`Consolas`, `Courier New`, etc.) into fenced blocks
/// - Embedded media and drawings (`<w:drawing>`) with alt text and relationships
/// - Bullet and numbered lists (`<w:numPr>`)
class LocalDocxParserService {
  const LocalDocxParserService();

  static const LocalDocxParserService instance = LocalDocxParserService();

  /// Extracts structured text from DOCX bytes synchronously.
  static String extractTextFromBytesSync(
    Uint8List bytes, {
    String? filename,
    ExtractionReport? report,
  }) {
    final docFilename = filename ?? 'document.docx';

    if (bytes.isEmpty) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_docx_archive',
        sampleText: 'Empty byte payload',
      );
      throw CorruptDocumentException(docFilename, 'DOCX file is empty');
    }

    Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_docx_archive',
        sampleText: '$e',
      );
      throw CorruptDocumentException(
        docFilename,
        'Malformed DOCX zip container: $e',
      );
    }

    final docFile = archive.findFile('word/document.xml');
    if (docFile == null) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'corrupted_docx_archive',
        sampleText: 'Missing word/document.xml',
      );
      throw CorruptDocumentException(
        docFilename,
        'DOCX archive missing word/document.xml',
      );
    }

    final docXml = utf8.decode(docFile.content as List<int>, allowMalformed: true);

    // 1. Build relationship map from word/_rels/document.xml.rels
    final relsMap = <String, String>{};
    final relsFile = archive.findFile('word/_rels/document.xml.rels');
    if (relsFile != null) {
      final relsXml = utf8.decode(
        relsFile.content as List<int>,
        allowMalformed: true,
      );
      final relMatches = RegExp(
        '<Relationship[^>]*Id="([^"]+)"[^>]*Target="([^"]+)"',
        caseSensitive: false,
      ).allMatches(relsXml);
      for (final rel in relMatches) {
        relsMap[rel.group(1)!] = rel.group(2)!;
      }
    }

    // 2. Parse body elements (<w:p> and <w:tbl>)
    return _parseDocxXml(docXml, relsMap: relsMap);
  }

  /// Extracts structured text asynchronously.
  Future<String> extractText(
    Uint8List bytes, {
    String? filename,
    ExtractionReport? report,
  }) async {
    return extractTextFromBytesSync(
      bytes,
      filename: filename,
      report: report,
    );
  }

  /// Parses the WordprocessingML document XML into Markdown.
  static String _parseDocxXml(
    String xml, {
    required Map<String, String> relsMap,
  }) {
    // Extract everything inside <w:body>...</w:body>
    final bodyMatch = RegExp(r'<w:body[^>]*>([\s\S]*?)</w:body>').firstMatch(xml);
    final bodyContent = bodyMatch != null ? bodyMatch.group(1)! : xml;

    final output = StringBuffer();
    final monospaceRunBuffer = <String>[];

    void flushMonospaceBlock() {
      if (monospaceRunBuffer.isEmpty) return;
      output.writeln('```');
      monospaceRunBuffer.forEach(output.writeln);
      output
        ..writeln('```')
        ..writeln();
      monospaceRunBuffer.clear();
    }

    // Match top-level paragraphs and tables sequentially
    final elementRegex = RegExp(
      r'<(w:p|w:tbl)[^>]*>([\s\S]*?)</\1>',
      caseSensitive: false,
    );

    final elements = elementRegex.allMatches(bodyContent);

    for (final element in elements) {
      final tag = element.group(1)!;
      final content = element.group(2)!;

      if (tag == 'w:tbl') {
        flushMonospaceBlock();
        final tableMarkdown = _parseDocxTable(content);
        if (tableMarkdown.isNotEmpty) {
          output
            ..writeln(tableMarkdown)
            ..writeln();
        }
      } else if (tag == 'w:p') {
        final paragraphData = _parseDocxParagraph(
          content,
          relsMap: relsMap,
        );

        if (paragraphData.isMonospaceCode) {
          monospaceRunBuffer.add(paragraphData.text);
        } else {
          flushMonospaceBlock();

          if (paragraphData.text.isNotEmpty) {
            if (paragraphData.headingLevel != null) {
              final hashes = '#' * paragraphData.headingLevel!;
              output.writeln('$hashes ${paragraphData.text}');
            } else if (paragraphData.isListItem) {
              output.writeln('- ${paragraphData.text}');
            } else {
              output.writeln(paragraphData.text);
            }
            output.writeln();
          }

          if (paragraphData.drawingMarkdown != null &&
              paragraphData.drawingMarkdown!.isNotEmpty) {
            output
              ..writeln(paragraphData.drawingMarkdown)
              ..writeln();
          }
        }
      }
    }

    flushMonospaceBlock();

    return _normalizeOutput(output.toString());
  }

  /// Parses a WordprocessingML table (`<w:tbl>`) into a Markdown table.
  static String _parseDocxTable(String tableContent) {
    final rows = <List<String>>[];

    final trMatches = RegExp(
      r'<w:tr[^>]*>([\s\S]*?)</w:tr>',
      caseSensitive: false,
    ).allMatches(tableContent);

    for (final tr in trMatches) {
      final trContent = tr.group(1)!;
      final cells = <String>[];

      final tcMatches = RegExp(
        r'<w:tc[^>]*>([\s\S]*?)</w:tc>',
        caseSensitive: false,
      ).allMatches(trContent);

      for (final tc in tcMatches) {
        final tcContent = tc.group(1)!;
        final cellText = _extractTextFromXmlRuns(tcContent)
            .replaceAll('\n', ' ')
            .replaceAll('|', r'\|')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        cells.add(cellText);
      }

      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }

    if (rows.isEmpty) {
      return '';
    }

    var maxCols = 0;
    for (final row in rows) {
      if (row.length > maxCols) maxCols = row.length;
    }
    if (maxCols == 0) return '';

    for (final row in rows) {
      while (row.length < maxCols) {
        row.add('');
      }
    }

    final buffer = StringBuffer()
      ..writeln('| ${rows.first.join(' | ')} |')
      ..writeln('| ${List.filled(maxCols, '---').join(' | ')} |');
    // Rows
    for (var i = 1; i < rows.length; i++) {
      buffer.writeln('| ${rows[i].join(' | ')} |');
    }

    return buffer.toString().trim();
  }

  /// Parses an individual DOCX paragraph (`<w:p>`).
  static _DocxParagraphData _parseDocxParagraph(
    String pContent, {
    required Map<String, String> relsMap,
  }) {
    int? headingLevel;
    var isListItem = false;
    var isMonospace = false;

    // 1. Check style and properties in <w:pPr>
    final pPrMatch = RegExp(r'<w:pPr[^>]*>([\s\S]*?)</w:pPr>').firstMatch(pContent);
    if (pPrMatch != null) {
      final pPrContent = pPrMatch.group(1)!;

      // Heading style
      final pStyleMatch = RegExp(
        '<w:pStyle[^>]*w:val="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(pPrContent);

      if (pStyleMatch != null) {
        final val = pStyleMatch.group(1)!.toLowerCase();
        if (val == 'title') {
          headingLevel = 1;
        } else if (val.startsWith('heading')) {
          final levelStr = val.replaceAll(RegExp('[^0-9]'), '');
          final lvl = int.tryParse(levelStr);
          if (lvl != null && lvl >= 1 && lvl <= 6) {
            headingLevel = lvl;
          } else {
            headingLevel = 1;
          }
        } else if (val.contains('code') || val.contains('source')) {
          isMonospace = true;
        }
      }

      // List item
      if (pPrContent.contains('<w:numPr>')) {
        isListItem = true;
      }

      // Check monospace font in pPr rPr
      if (RegExp(
        '<w:rFonts[^>]*w:ascii="(?:Courier New|Consolas|Monaco|Menlo|Courier|Lucida Console)"',
        caseSensitive: false,
      ).hasMatch(pPrContent)) {
        isMonospace = true;
      }
    }

    // 2. Also check if runs themselves have monospace fonts
    if (!isMonospace &&
        RegExp(
          '<w:rFonts[^>]*w:ascii="(?:Courier New|Consolas|Monaco|Menlo|Courier|Lucida Console)"',
          caseSensitive: false,
        ).hasMatch(pContent)) {
      isMonospace = true;
    }

    // 3. Extract Drawings / Pictures
    String? drawingMarkdown;
    final drawingMatch = RegExp(
      r'<w:drawing[^>]*>([\s\S]*?)</w:drawing>',
      caseSensitive: false,
    ).firstMatch(pContent);

    if (drawingMatch != null) {
      final drawingXml = drawingMatch.group(1)!;
      final docPrMatch = RegExp(
        'wp:docPr[^>]*descr="([^"]*)"',
        caseSensitive: false,
      ).firstMatch(drawingXml);
      final altText = docPrMatch?.group(1) ?? '';

      final blipMatch = RegExp(
        '<a:blip[^>]*r:embed="([^"]+)"',
        caseSensitive: false,
      ).firstMatch(drawingXml);
      final embedId = blipMatch?.group(1);
      final target = embedId != null ? (relsMap[embedId] ?? embedId) : '';

      if (target.isNotEmpty) {
        drawingMarkdown = '![$altText]($target)';
      }
    }

    // 4. Extract text runs & OMML math
    final text = _extractTextFromXmlRuns(pContent);

    return _DocxParagraphData(
      text: text,
      headingLevel: headingLevel,
      isListItem: isListItem,
      isMonospaceCode: isMonospace,
      drawingMarkdown: drawingMarkdown,
    );
  }

  /// Extracts text from runs (`<w:r>`) and OMML equations (`<m:oMath>`).
  static String _extractTextFromXmlRuns(String xml) {
    // Convert OMML math before stripping tags
    var content = xml.replaceAllMapped(
      RegExp(r'<m:oMath(?:Para)?[^>]*>([\s\S]*?)</m:oMath(?:Para)?>'),
      (m) {
        final latex = FormulaExtractionService.convertOmmlToLatex(m.group(0)!);
        return latex.isNotEmpty ? '<w:t> \$$latex\$ </w:t>' : '';
      },
    );

    // Replace break and tab tags with characters
    content = content
        .replaceAll(RegExp('<w:br[^>]*/>', caseSensitive: false), '\n')
        .replaceAll(RegExp('<w:tab[^>]*/>', caseSensitive: false), '\t');

    // Extract text in <w:t> tags
    final buffer = StringBuffer();
    final tMatches = RegExp(
      r'<w:t(?:[^>]*)>([\s\S]*?)</w:t>',
      caseSensitive: false,
    ).allMatches(content);

    if (tMatches.isNotEmpty) {
      for (final t in tMatches) {
        buffer.write(t.group(1));
      }
    } else {
      final stripped = content.replaceAll(RegExp('<[^>]+>'), '');
      buffer.write(stripped);
    }

    final raw = buffer.toString();
    return _unescapeXml(raw).trimRight();
  }

  /// Unescapes common XML character entities including hex/decimal references.
  static String _unescapeXml(String input) {
    var text = input;
    text = text.replaceAllMapped(RegExp('&#x([0-9a-fA-F]+);'), (m) {
      final code = int.tryParse(m.group(1)!, radix: 16);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    text = text.replaceAllMapped(RegExp('&#([0-9]+);'), (m) {
      final code = int.tryParse(m.group(1)!);
      return code != null ? String.fromCharCode(code) : m.group(0)!;
    });
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  /// Normalizes multiple blank lines.
  static String _normalizeOutput(String input) {
    final lines = input.split('\n');
    final cleaned = <String>[];
    var emptyLineCount = 0;

    for (final line in lines) {
      final trimmed = line.trimRight();
      if (trimmed.isEmpty) {
        emptyLineCount++;
        if (emptyLineCount <= 2) {
          cleaned.add('');
        }
      } else {
        emptyLineCount = 0;
        cleaned.add(trimmed);
      }
    }

    return cleaned.join('\n').trim();
  }
}

class _DocxParagraphData {
  const _DocxParagraphData({
    required this.text,
    this.headingLevel,
    this.isListItem = false,
    this.isMonospaceCode = false,
    this.drawingMarkdown,
  });

  final String text;
  final int? headingLevel;
  final bool isListItem;
  final bool isMonospaceCode;
  final String? drawingMarkdown;
}
