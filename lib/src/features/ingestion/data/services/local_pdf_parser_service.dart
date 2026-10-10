import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/pdf_figure_extractor.dart';
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

typedef OcrImageHandler = String Function(Uint8List imageBytes);

/// Lightweight layout representation of an extracted line for geometric sorting and analysis.
class PdfLineLayout {
  const PdfLineLayout({
    required this.text,
    required this.bounds,
    required this.fontSize,
    this.fontName = '',
    this.isBold = false,
  });

  factory PdfLineLayout.fromTextLine(TextLine line) {
    final isBold = line.fontStyle.toString().toLowerCase().contains('bold');
    return PdfLineLayout(
      text: line.text,
      bounds: line.bounds,
      fontSize: line.fontSize,
      fontName: line.fontName,
      isBold: isBold,
    );
  }

  final String text;
  final Rect bounds;
  final double fontSize;
  final String fontName;
  final bool isBold;
}

/// Local deterministic PDF text and image extraction service powered by
/// `syncfusion_flutter_pdf` and multi-tiered NLP heuristic chunking.
class LocalPdfParserService {
  const LocalPdfParserService({
    DocumentParserService documentParserService = const DocumentParserService(),
    OcrImageHandler? ocrHandler,
  })  : _documentParserService = documentParserService,
        _ocrHandler = ocrHandler;

  final DocumentParserService _documentParserService;
  final OcrImageHandler? _ocrHandler;

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
            final page = document.pages[i];
            pageText = _layoutAwarePageText(
              textLines,
              pageHeight: page.size.height,
              pageWidth: page.size.width,
              report: report,
            );
          }
        } on Object catch (_) {}

        if (pageText.trim().isEmpty) {
          pageText = extractor.extractText(startPageIndex: i);
        }

        // Per-page OCR fallback if page has zero extractable text streams
        if (pageText.trim().isEmpty) {
          report?.recordWarning(
            'Page ${i + 1} has zero text streams; attempting per-page OCR fallback.',
          );
          final ocr = _ocrHandler;
          if (ocr != null) {
            final pageImages = extractImagesFromPdfBytes(bytes);
            if (pageImages.isNotEmpty) {
              final ocrText = ocr(pageImages.first.bytes);
              if (ocrText.trim().isNotEmpty) {
                pageText = ocrText;
              }
            }
          }
          if (pageText.trim().isEmpty) {
            report?.recordDrop(
              page: i + 1,
              rule: 'scanned_page_no_text',
              sampleText: '[Page ${i + 1} has zero extractable text]',
            );
          }
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

  /// Identifies if a font name corresponds to a standard monospace family.
  static bool isMonospaceFont(String fontName) {
    if (fontName.isEmpty) return false;
    final lower = fontName.toLowerCase();
    return lower.contains('courier') ||
        lower.contains('consolas') ||
        lower.contains('menlo') ||
        lower.contains('monaco') ||
        lower.contains('monospace') ||
        lower.contains('mono') ||
        lower.contains('typewriter') ||
        lower.contains('sourcecodepro') ||
        lower.contains('source code pro') ||
        lower.contains('dejavusansmono') ||
        lower.contains('dejavu sans mono') ||
        lower.contains('inconsolata') ||
        lower.contains('fira') ||
        lower.contains('droid sans mono') ||
        lower.contains('roboto mono') ||
        lower.contains('liberation mono') ||
        lower.contains('lucida console') ||
        lower.contains('ocr') ||
        lower.contains('terminal');
  }

  /// Computes the statistical mode (most frequent) font size among body lines.
  static double _computeModeFontSize(List<PdfLineLayout> lines) {
    final counts = <double, int>{};
    for (final line in lines) {
      if (line.fontSize <= 0) continue;
      final bucket = (line.fontSize * 2).roundToDouble() / 2.0;
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    if (counts.isEmpty) return 10;
    var bestSize = 10.0;
    var maxCount = -1;
    for (final entry in counts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        bestSize = entry.key;
      }
    }
    return bestSize;
  }

  /// Dynamically infers Markdown heading levels (h1 = mode * 1.6, h2 = mode * 1.3, h3 = mode * 1.15).
  static int _detectHeadingLevel({
    required double fontSize,
    required double modeFontSize,
    required bool isBold,
    required int wordCount,
    required String text,
    required bool isMonospace,
  }) {
    if (isMonospace) return 0;
    if (wordCount > 16) return 0;
    final trimmed = text.trim();
    if (RegExp(r'[.!?,;:]$').hasMatch(trimmed) &&
        !RegExp(r'^\d+(\.\d+)*\s*').hasMatch(trimmed)) {
      return 0;
    }

    if (fontSize >= modeFontSize * 1.6) {
      return 1;
    } else if (fontSize >= modeFontSize * 1.3) {
      return 2;
    } else if (fontSize >= modeFontSize * 1.15) {
      return 3;
    } else if (isBold && fontSize >= modeFontSize * 1.05 && wordCount <= 12) {
      return 3;
    }
    return 0;
  }

  /// Identifies if a line contains distinct code syntax patterns.
  static bool _isCodeSyntaxLine(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.endsWith('{') ||
        trimmed.endsWith(';') ||
        trimmed.endsWith('}') ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/*')) {
      return true;
    }
    return RegExp(
      r'^(?:template\s*<|class\s+|struct\s+|public:|private:|protected:|using\s+|void\s+|int\s+|double\s+|return\s+|alignas\(|#include|import\s+)',
    ).hasMatch(trimmed);
  }

  /// Identifies running headers located strictly in the top 8% margin before body text.
  static bool _isMarginHeader({
    required PdfLineLayout line,
    required double topMargin,
  }) {
    if (line.bounds.top >= topMargin && line.bounds.bottom > topMargin) {
      return false;
    }
    final trimmed = line.text.trim();
    if (trimmed.isEmpty) return true;

    if (isMetadataOrRendererArtifact(trimmed)) {
      return true;
    }

    // Do not drop lines that contain sentence punctuation or Q/A markers
    final hasSentencePunctuation =
        RegExp(r'[.!?]\s+[A-Z]').hasMatch(trimmed) ||
            trimmed.startsWith('Q:') ||
            trimmed.startsWith('A:');
    if (hasSentencePunctuation) {
      return false;
    }

    final words = trimmed.split(RegExp(r'\s+'));
    return words.length <= 8;
  }

  /// Identifies running footers located strictly in the bottom 8% margin after body text.
  static bool _isMarginFooter({
    required PdfLineLayout line,
    required double bottomMargin,
  }) {
    if (line.bounds.bottom <= bottomMargin && line.bounds.top < bottomMargin) {
      return false;
    }
    final trimmed = line.text.trim();
    if (trimmed.isEmpty) return true;

    if (isMetadataOrRendererArtifact(trimmed)) {
      return true;
    }

    final words = trimmed.split(RegExp(r'\s+'));
    return words.length <= 8;
  }

  /// Determines if two connected words form a hyphenated compound (e.g., class-based, real-time).
  static bool _isHyphenatedCompound(String part1, String part2) {
    final p1 = part1.toLowerCase();
    final p2 = part2.toLowerCase();

    const compoundSuffixes = {
      'based',
      'oriented',
      'driven',
      'centric',
      'level',
      'safe',
      'free',
      'only',
      'ready',
      'type',
      'time',
      'bound',
      'rich',
      'wide',
      'like',
      'specific',
      'scale',
      'aware',
      'critical',
      'friendly',
      'proof',
      'sensitive',
      'side',
      'first',
      'point',
      'case',
      'party',
      'rate',
      'order',
      'end',
      'line',
      'size',
      'path',
    };

    if (compoundSuffixes.contains(p2)) {
      return true;
    }

    const compoundPrefixes = {
      'object',
      'class',
      'user',
      'real',
      'built',
      'read',
      'write',
      'zero',
      'state',
      'open',
      'source',
      'end',
      'high',
      'low',
      'full',
      'half',
      'well',
      'cross',
      'self',
      'fine',
      'co',
      'multi',
      'sub',
    };

    if (compoundPrefixes.contains(p1)) {
      if (p2.length >= 2) return true;
    }

    if (p1.length == 1) return true;

    return false;
  }

  /// Appends a prose line resolving hyphenation and preventing glued word boundaries.
  static void _appendProseLine(StringBuffer buffer, String nextText) {
    final current = buffer.toString();
    final hyphenMatch =
        RegExp(r'([A-Za-z0-9]+)\s*[-–—]\s*$').firstMatch(current);

    if (hyphenMatch != null) {
      final precedingWord = hyphenMatch.group(1)!;
      final nextWords = nextText.trim().split(RegExp(r'\s+'));
      final nextWord = nextWords.isNotEmpty
          ? nextWords.first.replaceAll(RegExp('[^A-Za-z0-9]'), '')
          : '';

      // Numeric ranges like "20-" and "40" -> "20-40"
      final isNumericRange = RegExp(r'^\d+$').hasMatch(precedingWord) &&
          RegExp(r'^\d+').hasMatch(nextWord);

      if (isNumericRange) {
        final cleanedPrefix = current.replaceAll(RegExp(r'\s*[-–—]\s*$'), '-');
        buffer
          ..clear()
          ..write(cleanedPrefix)
          ..write(nextText);
        return;
      }

      // Compound words like "class-" and "based" -> "class-based"
      if (_isHyphenatedCompound(precedingWord, nextWord)) {
        final prefix = current.substring(0, hyphenMatch.start);
        buffer
          ..clear()
          ..write(prefix)
          ..write('$precedingWord-')
          ..write(nextText);
        return;
      }

      // Genuine split words like "infor-" and "mation" -> "information"
      final prefix = current.substring(0, hyphenMatch.start);
      buffer
        ..clear()
        ..write(prefix)
        ..write(precedingWord)
        ..write(nextText);
      return;
    }

    // Normal line continuation with single space boundary
    buffer.write(' $nextText');
  }

  /// Sorts a single column top-to-bottom and merges line fragments on the same baseline.
  static List<PdfLineLayout> _sortAndMergeSingleColumn(List<PdfLineLayout> lines) {
    if (lines.length <= 1) return lines;

    final sorted = List<PdfLineLayout>.from(lines)
      ..sort((a, b) {
        final dy = a.bounds.top - b.bounds.top;
        if (dy.abs() > 2.5) {
          return dy < 0 ? -1 : 1;
        }
        return a.bounds.left.compareTo(b.bounds.left);
      });

    final result = <PdfLineLayout>[];
    var currentGroup = <PdfLineLayout>[sorted.first];

    for (var i = 1; i < sorted.length; i++) {
      final line = sorted[i];
      final baselineDiff =
          (line.bounds.top - currentGroup.first.bounds.top).abs();

      if (baselineDiff <= 2.5) {
        currentGroup.add(line);
      } else {
        result.add(_combineLineFragments(currentGroup));
        currentGroup = [line];
      }
    }
    if (currentGroup.isNotEmpty) {
      result.add(_combineLineFragments(currentGroup));
    }

    return result;
  }

  /// Combines horizontal fragments on the same baseline into a single coherent line.
  static PdfLineLayout _combineLineFragments(List<PdfLineLayout> fragments) {
    if (fragments.length == 1) return fragments.first;

    final first = fragments.first;
    final textBuffer = StringBuffer(first.text);

    for (var i = 1; i < fragments.length; i++) {
      final prev = fragments[i - 1];
      final curr = fragments[i];
      final gap = curr.bounds.left - prev.bounds.right;
      if (gap > 2.0 &&
          !textBuffer.toString().endsWith(' ') &&
          !curr.text.startsWith(' ')) {
        textBuffer.write(' ');
      }
      textBuffer.write(curr.text);
    }

    final left = first.bounds.left;
    final right = fragments.map((f) => f.bounds.right).fold<double>(0, math.max);
    final top =
        fragments.map((f) => f.bounds.top).fold(double.infinity, math.min);
    final bottom = fragments.map((f) => f.bounds.bottom).fold<double>(0, math.max);

    return PdfLineLayout(
      text: textBuffer.toString(),
      bounds: Rect.fromLTRB(left, top, right, bottom),
      fontSize: first.fontSize,
      fontName: first.fontName,
      isBold: fragments.any((f) => f.isBold),
    );
  }

  /// Multi-column geometric sort that orders text in natural human reading order.
  static List<PdfLineLayout> _geometricSort(List<PdfLineLayout> lines) {
    if (lines.length <= 1) return lines;

    final minX =
        lines.map((l) => l.bounds.left).fold(double.infinity, math.min);
    final maxX = lines.map((l) => l.bounds.right).fold<double>(0, math.max);
    final contentWidth = maxX - minX;

    if (contentWidth < 200) {
      return _sortAndMergeSingleColumn(lines);
    }

    final midX = minX + contentWidth / 2;

    final leftLines = <PdfLineLayout>[];
    final rightLines = <PdfLineLayout>[];
    final spanningLines = <PdfLineLayout>[];

    for (final line in lines) {
      final isSpanning = line.bounds.left < midX - 30 &&
          line.bounds.right > midX + 30 &&
          line.bounds.width >= contentWidth * 0.60;

      if (isSpanning) {
        spanningLines.add(line);
      } else {
        final centerX = line.bounds.left + line.bounds.width / 2;
        if (centerX < midX) {
          leftLines.add(line);
        } else {
          rightLines.add(line);
        }
      }
    }

    // Check for vertical overlap between left and right columns
    var overlapCount = 0;
    for (final l in leftLines) {
      for (final r in rightLines) {
        if (l.bounds.top < r.bounds.bottom - 4 &&
            l.bounds.bottom > r.bounds.top + 4) {
          overlapCount++;
          break;
        }
      }
      if (overlapCount >= 3) break;
    }

    // Single column with uneven margins
    if (overlapCount < 3) {
      return _sortAndMergeSingleColumn(lines);
    }

    // Multi-column without spanning lines: Column 1 then Column 2
    if (spanningLines.isEmpty) {
      final sortedLeft = _sortAndMergeSingleColumn(leftLines);
      final sortedRight = _sortAndMergeSingleColumn(rightLines);
      return [...sortedLeft, ...sortedRight];
    }

    // Multi-column with spanning elements: slice into vertical bands
    final sortedSpanning = List<PdfLineLayout>.from(spanningLines)
      ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    final result = <PdfLineLayout>[];
    var currentY = 0.0;

    for (final span in sortedSpanning) {
      final bandLines = lines.where((l) {
        if (spanningLines.contains(l)) return false;
        return l.bounds.bottom <= span.bounds.top + 4 &&
            l.bounds.top >= currentY - 4;
      }).toList();

      if (bandLines.isNotEmpty) {
        final bLeft = bandLines
            .where((l) => (l.bounds.left + l.bounds.width / 2) < midX)
            .toList();
        final bRight = bandLines
            .where((l) => (l.bounds.left + l.bounds.width / 2) >= midX)
            .toList();
        result
          ..addAll(_sortAndMergeSingleColumn(bLeft))
          ..addAll(_sortAndMergeSingleColumn(bRight));
      }

      result.add(span);
      currentY = span.bounds.bottom;
    }

    final trailingLines = lines.where((l) {
      if (spanningLines.contains(l)) return false;
      return l.bounds.top >= currentY - 4;
    }).toList();

    if (trailingLines.isNotEmpty) {
      final tLeft = trailingLines
          .where((l) => (l.bounds.left + l.bounds.width / 2) < midX)
          .toList();
      final tRight = trailingLines
          .where((l) => (l.bounds.left + l.bounds.width / 2) >= midX)
          .toList();
      result
        ..addAll(_sortAndMergeSingleColumn(tLeft))
        ..addAll(_sortAndMergeSingleColumn(tRight));
    }

    return result;
  }

  /// Formats monospace lines into an indented fenced code block without headings.
  static String _formatCodeBlock(List<PdfLineLayout> lines) {
    if (lines.isEmpty) return '';

    final mergedLines = _sortAndMergeSingleColumn(lines);
    final minLeft = mergedLines
        .map((l) => l.bounds.left)
        .fold(double.infinity, math.min);
    final baseFontSize =
        mergedLines.first.fontSize > 0 ? mergedLines.first.fontSize : 9.0;
    final charWidth = baseFontSize * 0.6;

    final formatted = <String>[];
    for (final line in mergedLines) {
      final indentSpaces = math.max(
        0,
        ((line.bounds.left - minLeft) /
                (charWidth > 0 ? charWidth : 6.0))
            .round(),
      );
      final indent = ' ' * indentSpaces;
      formatted.add('$indent${line.text.trimRight()}');
    }

    return '```\n${formatted.join('\n')}\n```';
  }

  /// Layout-aware page text processor operating on structured [PdfLineLayout] streams.
  static String layoutAwareLines(
    List<PdfLineLayout> lines, {
    double pageHeight = 0,
    double pageWidth = 0,
    ExtractionReport? report,
  }) {
    if (lines.isEmpty) return '';

    final effHeight = pageHeight > 0
        ? pageHeight
        : lines.map((l) => l.bounds.bottom).fold<double>(0, math.max);
    final topMargin = effHeight * 0.08;
    final bottomMargin = effHeight * 0.92;

    final sortedByY = List<PdfLineLayout>.from(lines)
      ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));

    var bodyStarted = false;
    final bodyLines = <PdfLineLayout>[];

    for (final line in sortedByY) {
      final raw = line.text.trim();
      if (raw.isEmpty) continue;

      if (!bodyStarted) {
        if (_isMarginHeader(line: line, topMargin: topMargin)) {
          report?.recordDrop(
            rule: 'margin_header_footer',
            sampleText: line.text,
          );
          continue;
        } else {
          bodyStarted = true;
        }
      }

      if (_isMarginFooter(line: line, bottomMargin: bottomMargin)) {
        report?.recordDrop(
          rule: 'margin_header_footer',
          sampleText: line.text,
        );
        continue;
      }

      bodyLines.add(line);
    }

    if (bodyLines.isEmpty) return '';

    final orderedLines = _geometricSort(bodyLines);
    final modeFontSize = _computeModeFontSize(orderedLines);
    final lineHeights = orderedLines
        .map((l) => l.bounds.height)
        .where((h) => h > 0)
        .toList()
      ..sort();
    final medianLineHeight = lineHeights.isNotEmpty
        ? lineHeights[lineHeights.length ~/ 2]
        : 12.0;

    final buffer = StringBuffer();
    var prevWasHeading = false;
    var prevWasBullet = false;
    var prevWasCode = false;
    var i = 0;

    while (i < orderedLines.length) {
      final line = orderedLines[i];
      final isMono = isMonospaceFont(line.fontName);

      // Recognize monospace fonts as code blocks
      if (isMono) {
        final codeLines = <PdfLineLayout>[line];
        var j = i + 1;
        while (j < orderedLines.length) {
          final nextLine = orderedLines[j];
          final nextIsMono = isMonospaceFont(nextLine.fontName);
          if (nextIsMono) {
            codeLines.add(nextLine);
            j++;
          } else {
            break;
          }
        }

        final codeBlockStr = _formatCodeBlock(codeLines);
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write(codeBlockStr);

        prevWasHeading = false;
        prevWasBullet = false;
        prevWasCode = true;
        i = j;
        continue;
      }

      final rawText = line.text.trim();
      final words = rawText.split(RegExp(r'\s+'));
      final isCode = _isCodeSyntaxLine(rawText);

      var headingLevel = _detectHeadingLevel(
        fontSize: line.fontSize,
        modeFontSize: modeFontSize,
        isBold: line.isBold,
        wordCount: words.length,
        text: rawText,
        isMonospace: false,
      );

      // Check for numbered section headings (e.g., "1. Memory Allocation Overhead")
      if (headingLevel == 0 &&
          !isCode &&
          words.length <= 14 &&
          !rawText.endsWith('.') &&
          RegExp(r'^\d+(\.\d+)*\s+[A-Z]').hasMatch(rawText)) {
        headingLevel = 2;
      }

      final isBullet = !isCode && headingLevel == 0 && _bulletPrefixRe.hasMatch(rawText);

      if (headingLevel > 0) {
        final prefix = '#' * headingLevel;
        if (buffer.isNotEmpty) {
          buffer.write('\n\n');
        }
        buffer.write('$prefix $rawText');
        prevWasHeading = true;
        prevWasBullet = false;
        prevWasCode = false;
        i++;
        continue;
      }

      if (isCode) {
        if (buffer.isNotEmpty) {
          buffer.write(prevWasCode ? '\n' : '\n\n');
        }
        buffer.write(rawText);
        prevWasHeading = false;
        prevWasBullet = false;
        prevWasCode = true;
        i++;
        continue;
      }

      if (isBullet) {
        if (buffer.isNotEmpty) {
          buffer.write('\n');
        }
        buffer.write(rawText);
        prevWasHeading = false;
        prevWasBullet = true;
        prevWasCode = false;
        i++;
        continue;
      }

      // Prose line: append with paragraph spacing or hyphenation resolution
      if (buffer.isEmpty) {
        buffer.write(rawText);
      } else {
        final prevLine = orderedLines[i - 1];
        final gap = line.bounds.top - prevLine.bounds.bottom;
        final prevEndsSentence =
            RegExp(r'[.!?:]$').hasMatch(prevLine.text.trim());
        final isParagraphBreak = prevWasHeading ||
            prevWasBullet ||
            prevWasCode ||
            (gap > medianLineHeight * 0.8 && prevEndsSentence) ||
            gap > medianLineHeight * 1.5;

        if (isParagraphBreak) {
          buffer.write('\n\n$rawText');
        } else {
          _appendProseLine(buffer, rawText);
        }
      }

      prevWasHeading = false;
      prevWasBullet = false;
      prevWasCode = false;
      i++;
    }

    return buffer.toString().trim();
  }

  static String _layoutAwarePageText(
    List<TextLine> textLines, {
    double pageHeight = 0,
    double pageWidth = 0,
    ExtractionReport? report,
  }) {
    if (textLines.isEmpty) return '';
    final lines = textLines.map(PdfLineLayout.fromTextLine).toList();
    return layoutAwareLines(
      lines,
      pageHeight: pageHeight,
      pageWidth: pageWidth,
      report: report,
    );
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

  /// Extracts strongly-typed [ExtractedPdfFigure]s with bounding box geometry,
  /// page index, and spatial caption association.
  List<ExtractedPdfFigure> extractFiguresFromPdfBytes(
    Uint8List bytes, {
    List<String>? pageTexts,
  }) {
    return const PdfFigureExtractor().extractFigures(bytes, pageTexts: pageTexts);
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
