import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/entities/extraction_report.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class _PdfExtractParams {
  const _PdfExtractParams({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

class _PdfFlashcardParseParams {
  const _PdfFlashcardParseParams({
    required this.documentId,
    required this.bytes,
    required this.filename,
    required this.imageUrls,
  });

  final String documentId;
  final Uint8List bytes;
  final String filename;
  final List<String> imageUrls;
}

/// Local deterministic PDF text and image extraction service powered by
/// `syncfusion_flutter_pdf` and multi-tiered NLP heuristic chunking.
class LocalPdfParserService {
  const LocalPdfParserService({
    DocumentParserService documentParserService = const DocumentParserService(),
  }) : _documentParserService = documentParserService;

  final DocumentParserService _documentParserService;

  /// Extracts raw text from PDF binary bytes in a background isolate.
  Future<String> extractText(
    Uint8List bytes, {
    String filename = 'document.pdf',
  }) async {
    if (bytes.isEmpty) return '';
    if (kIsWeb) {
      return extractTextFromPdfBytes(bytes, filename: filename);
    }
    return compute(
      _isolateExtractPdfText,
      _PdfExtractParams(bytes: bytes, filename: filename),
    );
  }

  static String _isolateExtractPdfText(_PdfExtractParams params) {
    return const LocalPdfParserService().extractTextFromPdfBytes(
      params.bytes,
      filename: params.filename,
    );
  }

  /// Extracts raw text page-by-page from a local PDF [File] in a background isolate.
  Future<String> extractTextFromPdfFile(
    File file, {
    String filename = 'document.pdf',
  }) async {
    final bytes = await file.readAsBytes();
    return extractText(bytes, filename: filename);
  }

  /// Extracts raw text page-by-page from raw PDF [bytes] using Syncfusion,
  /// applying dynamic cross-page repeating line frequency analysis to strip
  /// marginalia/headers/footers, UTF-8 character validation, vector/graphics
  /// stream exclusion, and grammar-aware line-unwrapping.
  String extractTextFromPdfBytes(
    Uint8List bytes, {
    String filename = 'document.pdf',
    ExtractionReport? report,
  }) {
    if (bytes.isEmpty) return '';

    // Fast check for PDF encryption dictionary
    if (_hasPdfEncryption(bytes)) {
      report?.isEncrypted = true;
      report?.recordWarning('PDF contains /Encrypt dictionary');
      throw EncryptedPdfException(filename);
    }

    // Validate minimal PDF header
    final probeLen = bytes.length < 1024 ? bytes.length : 1024;
    final probeStr = String.fromCharCodes(bytes.sublist(0, probeLen));
    if (!probeStr.contains('%PDF')) {
      report?.isCorrupt = true;
      report?.recordDrop(
        rule: 'invalid_pdf_header',
        sampleText: probeStr.substring(0, math.min(probeStr.length, 50)),
      );
      throw CorruptDocumentException(filename, 'File lacks valid %PDF header.');
    }

    PdfDocument? document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } on Object catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('password') || err.contains('encrypt') || _hasPdfEncryption(bytes)) {
        report?.isEncrypted = true;
        report?.recordWarning('PDF is encrypted: $e');
        throw EncryptedPdfException(filename);
      }

      final fallbackText = _documentParserService.extractRawPdfStreamText(bytes);
      final sanitizedFallback = sanitizeExtractedText(fallbackText, report: report);
      if (sanitizedFallback.trim().isEmpty) {
        report?.isCorrupt = true;
        report?.recordDrop(rule: 'unrecoverable_pdf_syntax', sampleText: '$e');
        throw CorruptDocumentException(filename, 'Unrecoverable PDF syntax: $e');
      }
      return sanitizedFallback;
    }

    final pageTexts = <String>[];
    var pageCount = 0;
    try {
      pageCount = document.pages.count;
      final extractor = PdfTextExtractor(document);

      for (var i = 0; i < pageCount; i++) {
        var pageText = '';
        try {
          final textLines = extractor.extractTextLines(startPageIndex: i);
          if (textLines.isNotEmpty) {
            pageText = _layoutAwarePageText(textLines);
          }
        } on Object catch (_) {}

        if (pageText.trim().isEmpty) {
          pageText = extractor.extractText(startPageIndex: i);
        }

        // Restore ligatures
        pageText = pageText
            .replaceAll('ﬁ', 'fi')
            .replaceAll('ﬂ', 'fl')
            .replaceAll('ﬀ', 'ff')
            .replaceAll('ﬃ', 'ffi')
            .replaceAll('ﬄ', 'ffl');

        final lower = pageText.toLowerCase().trim();

        // Skip non-educational front-matter and back-matter pages
        if (_isNonEducationalPage(lower, pageText)) {
          report?.recordDrop(
            page: i + 1,
            rule: 'non_educational_page',
            sampleText: pageText,
          );
          continue;
        }

        if (pageText.trim().isNotEmpty) {
          pageTexts.add(pageText);
        }
      }
    } finally {
      document.dispose();
    }

    if (pageTexts.isNotEmpty) {
      final sanitized = sanitizeExtractedPages(pageTexts, report: report);
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }

    final fallbackText = _documentParserService.extractRawPdfStreamText(bytes);
    final sanitizedFallback = sanitizeExtractedText(fallbackText, report: report);
    if (sanitizedFallback.isNotEmpty) {
      return sanitizedFallback;
    }

    // If PDF has pages but zero extractable text streams across all extraction attempts
    if (pageCount > 0) {
      report?.isScanned = true;
      report?.recordWarning('Document has $pageCount page(s) but zero text streams.');
      throw ScannedDocumentException(
        filename,
        'Document has $pageCount page(s) with zero extractable text streams (scanned or image-only).',
      );
    }

    return '';
  }

  static bool _hasPdfEncryption(Uint8List bytes) {
    if (bytes.isEmpty) return false;
    final target = [47, 69, 110, 99, 114, 121, 112, 116]; // '/Encrypt'
    var matchIdx = 0;
    for (var i = 0; i < bytes.length; i++) {
      if (bytes[i] == target[matchIdx]) {
        matchIdx++;
        if (matchIdx == target.length) {
          if (i + 1 >= bytes.length ||
              bytes[i + 1] <= 32 ||
              bytes[i + 1] == 47 ||
              bytes[i + 1] == 60) {
            return true;
          }
        }
      } else {
        matchIdx = bytes[i] == target[0] ? 1 : 0;
      }
    }
    return false;
  }

  /// Dynamically sanitizes extracted pages by computing line occurrence frequency
  /// across pages to automatically identify and eliminate repeating headers,
  /// footers, watermarks, and marginalia without hardcoded rules.
  static String sanitizeExtractedPages(
    List<String> pages, {
    ExtractionReport? report,
  }) {
    if (pages.isEmpty) return '';

    // 1. Compute line frequency across all pages to detect dynamic repeating headers/footers
    final linePageCounts = <String, int>{};
    final pageLinesList = <List<String>>[];

    for (final page in pages) {
      final lines = page.split('\n');
      final seenOnThisPage = <String>{};
      var inCode = false;
      var inMath = false;
      String? codeFence;

      for (final raw in lines) {
        final trimmed = raw.trim();
        if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
          final fence = trimmed.substring(0, 3);
          if (!inCode) {
            inCode = true;
            codeFence = fence;
          } else if (fence == codeFence) {
            inCode = false;
            codeFence = null;
          }
          continue;
        }
        if (inCode) continue;

        if (trimmed.startsWith(r'$$') || trimmed.startsWith(r'\[')) {
          if (!inMath) {
            inMath = true;
            if (trimmed.length > 2 && (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]'))) {
              inMath = false;
            }
          } else {
            inMath = false;
          }
          continue;
        }
        if (trimmed.startsWith(r'\begin{')) {
          inMath = true;
          continue;
        }
        if (inMath) {
          if (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]') || trimmed.startsWith(r'\end{')) {
            inMath = false;
          }
          continue;
        }

        if (trimmed.isEmpty) continue;
        final normalized = _normalizeLineForFrequency(trimmed);
        final wordCount = normalized
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .length;
        if (normalized.length >= 8 &&
            wordCount >= 2 &&
            !seenOnThisPage.contains(normalized)) {
          seenOnThisPage.add(normalized);
          linePageCounts[normalized] = (linePageCounts[normalized] ?? 0) + 1;
        }
      }
      pageLinesList.add(lines);
    }

    // A line appearing on >= 40% of pages in a multi-page document is classified as repeating marginalia
    final totalPages = pages.length;
    final repeatingMarginalia = <String>{};
    if (totalPages >= 2) {
      for (final entry in linePageCounts.entries) {
        if (entry.value >= 2 && (entry.value / totalPages >= 0.40)) {
          repeatingMarginalia.add(entry.key);
        }
      }
    }

    final pageOutputs = <String>[];
    for (final page in pages) {
      final lines = page.split('\n');
      final cleanLines = <String>[];
      var inCode = false;
      var inMath = false;
      String? codeFence;

      for (final raw in lines) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          cleanLines.add('');
          continue;
        }

        // Code fences and interior lines are preserved byte-for-byte
        if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
          final fence = trimmed.substring(0, 3);
          if (!inCode) {
            inCode = true;
            codeFence = fence;
          } else if (fence == codeFence) {
            inCode = false;
            codeFence = null;
          }
          cleanLines.add(raw);
          continue;
        }
        if (inCode) {
          cleanLines.add(raw);
          continue;
        }

        // Math blocks and interior lines are preserved byte-for-byte
        if (trimmed.startsWith(r'$$') || trimmed.startsWith(r'\[')) {
          if (!inMath) {
            inMath = true;
            if (trimmed.length > 2 && (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]'))) {
              inMath = false;
            }
          } else {
            inMath = false;
          }
          cleanLines.add(raw);
          continue;
        }
        if (trimmed.startsWith(r'\begin{')) {
          inMath = true;
          cleanLines.add(raw);
          continue;
        }
        if (inMath) {
          if (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]') || trimmed.startsWith(r'\end{')) {
            inMath = false;
          }
          cleanLines.add(raw);
          continue;
        }

        if (report != null) {
          report.totalLinesProcessed++;
        }
        final normalized = _normalizeLineForFrequency(trimmed);
        if (repeatingMarginalia.contains(normalized)) {
          report?.recordDrop(rule: 'repeating_marginalia', sampleText: raw);
          continue;
        }
        if (isMetadataOrRendererArtifact(trimmed)) {
          report?.recordDrop(
            rule: 'renderer_or_page_number_artifact',
            sampleText: raw,
          );
          continue;
        }
        if (isCorruptedBinaryNoise(trimmed)) {
          report?.recordDrop(rule: 'corrupted_binary_noise', sampleText: raw);
          continue;
        }
        if (report != null) {
          report.totalLinesRetained++;
        }
        cleanLines.add(trimmed);
      }
      final cleanedPage = cleanLines.join('\n').trim();
      if (cleanedPage.isNotEmpty) {
        pageOutputs.add(cleanedPage);
      }
    }

    return pageOutputs.join('\n\n');
  }

  /// Preserved for backward-compatibility; no-op to prevent destructive text
  /// mutations (e.g. "Vitamin C is" -> "Vitamin Cis", "Plan B or" -> "Plan Bor").
  static String repairDetachedInitialCapitals(String text) => text;

  /// Sanitizes raw single-block extracted text into coherent paragraphs.
  static String sanitizeExtractedText(
    String rawText, {
    ExtractionReport? report,
  }) {
    if (rawText.isEmpty) return '';
    return sanitizeExtractedPages([rawText], report: report);
  }

  static String _normalizeLineForFrequency(String line) {
    return line
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\d+'), '')
        .trim();
  }

  static final _bulletPrefixRe = RegExp(
    r'^([-•*●▪◦–—]|\d{1,2}[.)]|[a-z][.)])\s+(\S.*)$',
  );

  static String _layoutAwarePageText(List<TextLine> textLines) {
    if (textLines.isEmpty) return '';

    // Maintain native reading order (multi-column friendly)
    final sorted = textLines;

    final fontSizes = sorted
        .map((l) => l.fontSize)
        .where((s) => s > 0)
        .toList()
      ..sort();
    final medianFontSize = fontSizes.isNotEmpty
        ? fontSizes[fontSizes.length ~/ 2]
        : 10.0;

    final lineHeights = sorted
        .map((l) => l.bounds.height)
        .where((h) => h > 0)
        .toList()
      ..sort();
    final medianLineHeight = lineHeights.isNotEmpty
        ? lineHeights[lineHeights.length ~/ 2]
        : 12.0;

    final buffer = StringBuffer();
    TextLine? prev;
    var prevWasHeading = false;
    var prevWasBullet = false;

    for (final line in sorted) {
      final rawText = line.text.trim();
      if (rawText.isEmpty) continue;

      final isBold = line.fontStyle.toString().toLowerCase().contains('bold');
      final wordCount = rawText.split(RegExp(r'\s+')).length;
      final isHeading = (line.fontSize >= medianFontSize * 1.15 ||
              (isBold && line.fontSize >= medianFontSize)) &&
          wordCount <= 14 &&
          !RegExp(r'[.!?,;:]$').hasMatch(rawText);

      final isBullet = _bulletPrefixRe.hasMatch(rawText);

      if (prev != null) {
        final gap = line.bounds.top - prev.bounds.bottom;
        final prevEndsSentence = RegExp(r'[.!?:]$').hasMatch(prev.text.trim());
        final isParagraphBreak =
            (gap > medianLineHeight * 0.75 && prevEndsSentence) ||
            gap > medianLineHeight * 1.5;

        if (isHeading || prevWasHeading || isParagraphBreak) {
          buffer.write('\n\n');
        } else if (isBullet || prevWasBullet) {
          buffer.write('\n');
        } else {
          final currentStr = buffer.toString();
          if (RegExp(r'[a-z]-$').hasMatch(currentStr) &&
              RegExp('^[a-z]').hasMatch(rawText)) {
            final withoutHyphen = currentStr.substring(0, currentStr.length - 1);
            buffer
              ..clear()
              ..write(withoutHyphen);
          } else if (RegExp(r'\d-$').hasMatch(currentStr) &&
              RegExp(r'^\d').hasMatch(rawText)) {
            // Preserve number ranges like "20-" and "40" -> "20-40"
          } else {
            buffer.write(' ');
          }
        }
      }

      if (isHeading) {
        buffer.write('## $rawText');
        prevWasHeading = true;
        prevWasBullet = false;
      } else {
        buffer.write(rawText);
        prevWasHeading = false;
        prevWasBullet = isBullet;
      }

      prev = line;
    }

    return buffer.toString();
  }


  /// Discards strings where more than 10% of characters are non-printable,
  /// control characters, or fall outside standard alphanumeric/punctuation ranges.
  static bool isCorruptedBinaryNoise(String line) {
    if (line.isEmpty) return true;

    final runes = line.runes.toList();
    var nonPrintableCount = 0;
    var alphaNumericCount = 0;

    for (final r in runes) {
      // Control characters (excluding \t, \n, \r)
      if ((r >= 0 && r < 9) ||
          (r >= 11 && r <= 12) ||
          (r >= 14 && r < 32) ||
          r == 127) {
        nonPrintableCount++;
        continue;
      }

      // Standard printable ASCII (32-126)
      if (r >= 32 && r <= 126) {
        if ((r >= 65 && r <= 90) ||
            (r >= 97 && r <= 122) ||
            (r >= 48 && r <= 57)) {
          alphaNumericCount++;
        }
        continue;
      }

      // Common valid Unicode text & symbol blocks
      if ((r >= 160 && r <= 591) ||
          (r >= 0x0370 && r <= 0x03FF) ||
          (r >= 0x2000 && r <= 0x206F) ||
          (r >= 0x20A0 && r <= 0x20CF) ||
          (r >= 0x2100 && r <= 0x218F) ||
          (r >= 0x2200 && r <= 0x22FF)) {
        if ((r >= 192 && r <= 255) ||
            (r >= 256 && r <= 591) ||
            (r >= 0x0370 && r <= 0x03FF)) {
          alphaNumericCount++;
        }
        continue;
      }

      nonPrintableCount++;
    }

    // Discard any line where > 10% of characters are non-printable or corrupted
    if (nonPrintableCount / runes.length > 0.10) {
      return true;
    }

    // If line has more than 10 characters and has virtually no alphanumeric content (< 25%), drop
    if (runes.length > 10 && (alphaNumericCount / runes.length < 0.25)) {
      final isMath = line.contains(RegExp(r'[\$\\=><\+\-\*\/\^]'));
      if (!isMath) {
        return true;
      }
    }

    return false;
  }

  /// Dynamically identifies generic PDF generator metadata, renderer strings,
  /// and arbitrary page counter patterns.
  static bool isMetadataOrRendererArtifact(String line) {
    final lower = line.toLowerCase().trim();

    // Universal pagination formats: "Page 1 of 12", "1 / 15", "- 12 -", "[ 1 ]", standalone digits
    if (RegExp(
      r'^(?:page\s+\d+(\s+(?:of|/)\s+\d+)?|\d+\s*/\s*\d+|\-+\s*\d+\s*\-+|\(?\s*\d+\s*\)?|\d+)$',
      caseSensitive: false,
    ).hasMatch(lower)) {
      return true;
    }

    // Standard PDF renderer & engine metadata tags
    final metadataKeywords = [
      'skia/pdf',
      'pdfium',
      'cairo',
      'quartz 10',
      'ghostscript',
      'adobe pdf library',
      'prince xml',
      'wkhtmltopdf',
      'itext',
      'pdftex',
      'creationdate',
      'moddate',
      'producer (',
      'creator (',
      '/subtype /form',
      '/subtype /image',
      '/fontdescriptor',
      '/tounicode',
      '/cidinit',
      '/colorspace',
      '/iccbased',
    ];

    for (final keyword in metadataKeywords) {
      if (lower.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  /// Extracts embedded images and diagrams deterministically from PDF bytes.
  List<ExtractedImageAttachment> extractImagesFromPdfBytes(Uint8List bytes) {
    return _documentParserService.extractImagesFromPdfBytes(bytes);
  }

  /// Parses a local PDF file and synthesizes structured flashcard snippets in a background isolate.
  Future<List<OcrExtractionModel>> parsePdfFileToFlashcards({
    required String documentId,
    required File file,
    required String filename,
    List<String> imageUrls = const [],
  }) async {
    final bytes = await file.readAsBytes();
    return compute(
      _isolateParsePdfToFlashcards,
      _PdfFlashcardParseParams(
        documentId: documentId,
        bytes: bytes,
        filename: filename,
        imageUrls: imageUrls,
      ),
    );
  }

  static List<OcrExtractionModel> _isolateParsePdfToFlashcards(
    _PdfFlashcardParseParams params,
  ) {
    return const LocalPdfParserService().parsePdfBytesToFlashcards(
      documentId: params.documentId,
      bytes: params.bytes,
      filename: params.filename,
      imageUrls: params.imageUrls,
    );
  }

  /// Parses raw PDF bytes and synthesizes structured flashcard snippets
  /// using the multi-tiered heuristic engine.
  List<OcrExtractionModel> parsePdfBytesToFlashcards({
    required String documentId,
    required Uint8List bytes,
    required String filename,
    List<String> imageUrls = const [],
  }) {
    final fullText = extractTextFromPdfBytes(bytes, filename: filename);
    return _documentParserService.synthesizeSnippetsFromDocument(
      documentId: documentId,
      fullText: fullText,
      filename: filename,
      imageUrls: imageUrls,
    );
  }

  /// Identifies front-matter (Table of Contents, Copyright, Acknowledgments, Prefaces)
  /// and back-matter (References, Bibliography, Index, Citations) pages to bypass.
  static bool _isNonEducationalPage(String lower, String rawPageText) {
    if (lower.isEmpty) return true;

    // Check first 6 non-empty lines for table of contents, preface, copyright, etc.
    final firstLines = lower
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .take(6)
        .toList();
    for (final line in firstLines) {
      if (line == 'contents' ||
          line == 'table of contents' ||
          line == 'brief contents' ||
          line.startsWith('table of contents') ||
          line.startsWith('contents') ||
          line == 'preface' ||
          line == 'foreword' ||
          line == 'acknowledgments' ||
          line == 'acknowledgements' ||
          line == 'copyright' ||
          line.startsWith('copyright ©') ||
          line == 'references' ||
          line == 'index') {
        return true;
      }
    }

    if (RegExp(r'\bcopyright\s+(?:©|\(c\))?\s*\d{4}\b', caseSensitive: false).hasMatch(lower) &&
        (lower.contains('all rights reserved') || lower.contains('printed in'))) {
      return true;
    }

    // Table of contents dot line pattern (e.g. "Chapter 1 . . . . 15")
    final dotLines = rawPageText
        .split('\n')
        .where((l) => RegExp(r'\.{3,}|\.\s*\.\s*\.').hasMatch(l))
        .length;
    if (dotLines >= 3) return true;

    // Table of contents page-number pattern: >= 35% of lines end with page numbers
    final lines = rawPageText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length >= 6) {
      final tocPattern = RegExp(
        r'^(?:\d+(?:\.\d+)*\s+)?[A-Z].*?\s+\d{1,4}$',
      );
      final tocMatches = lines.where(tocPattern.hasMatch).length;
      if (tocMatches / lines.length >= 0.35) {
        return true;
      }
    }

    // Direct front/back matter page headers or title starts
    final startsWithNoise = lower.startsWith('preface') ||
        lower.startsWith('foreword') ||
        lower.startsWith('acknowledgment') ||
        lower.startsWith('acknowledgement') ||
        lower.startsWith('acknowledgements') ||
        lower.startsWith('acknowledgments') ||
        lower.startsWith('dedication') ||
        lower.startsWith('about the author') ||
        lower.startsWith('about the contributors') ||
        lower.startsWith('table of contents') ||
        lower.startsWith('contents') ||
        lower.startsWith('copyright ©') ||
        lower.startsWith('copyright') ||
        lower.startsWith('all rights reserved') ||
        lower.startsWith('references') ||
        lower.startsWith('reference list') ||
        lower.startsWith('bibliography') ||
        lower.startsWith('works cited') ||
        lower.startsWith('literature cited') ||
        lower.startsWith('index') ||
        lower.startsWith('subject index') ||
        lower.startsWith('author index');

    if (startsWithNoise) return true;

    // Check if page consists mainly of reference citations or index numbers
    if (lower.contains('references') || lower.contains('bibliography')) {
      final citationLines = lines.where((l) => RegExp(r'^(?:\[\d+\]|\d+\.|\b[A-Z][a-z]+,\s+[A-Z]\.).*?\(\d{4}\)').hasMatch(l)).length;
      if (lines.isNotEmpty && (citationLines / lines.length > 0.40)) {
        return true;
      }
    }

    return false;
  }
}
