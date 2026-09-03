import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

/// Service responsible for extracting structured text and titles from `.pptx` presentations
/// completely offline in background isolates.
class LocalPptxParserService {
  const LocalPptxParserService();

  /// Extracts structured text from PPTX binary bytes in a background isolate.
  Future<String> extractText(Uint8List bytes) async {
    if (bytes.isEmpty) return '';
    return compute(_parsePptxBytesInIsolate, bytes);
  }

  /// Parses PPTX bytes into a unified text string grouping slide titles with body bullet points.
  static String _parsePptxBytesInIsolate(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final slideEntries = <int, ArchiveFile>{};

      // Collect all slide XML entries and order them by slide number
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

      final sortedSlideNumbers = slideEntries.keys.toList()..sort();
      final buffer = StringBuffer();

      for (final slideNum in sortedSlideNumbers) {
        final file = slideEntries[slideNum]!;
        final content = utf8.decode(file.content as List<int>, allowMalformed: true);
        final slideText = _parseSlideXml(content, slideNum);
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

  /// Parses a single slide XML document extracting shapes, titles, and body paragraphs.
  static String _parseSlideXml(String xmlContent, int slideNumber) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final shapes = document.findAllElements('p:sp');
      final paragraphs = <String>[];
      String? slideTitle;

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
      if (slideTitle == null && paragraphs.isNotEmpty && paragraphs.first.length < 80) {
        slideTitle = paragraphs.removeAt(0);
      }

      final slideBuffer = StringBuffer();
      slideBuffer.writeln('## Slide $slideNumber${slideTitle != null ? ': $slideTitle' : ''}');
      for (final p in paragraphs) {
        slideBuffer.writeln('• $p');
      }

      return slideBuffer.toString().trim();
    } catch (e) {
      return '';
    }
  }
}
