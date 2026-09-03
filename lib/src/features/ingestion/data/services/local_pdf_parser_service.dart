import 'dart:io';
import 'dart:typed_data';

import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Local deterministic PDF text and image extraction service powered by
/// `syncfusion_flutter_pdf` and multi-tiered NLP heuristic chunking.
class LocalPdfParserService {
  const LocalPdfParserService({
    DocumentParserService documentParserService = const DocumentParserService(),
  }) : _documentParserService = documentParserService;

  final DocumentParserService _documentParserService;

  /// Extracts raw text from PDF binary bytes.
  Future<String> extractText(
    Uint8List bytes, {
    String filename = 'document.pdf',
  }) async {
    return extractTextFromPdfBytes(bytes, filename: filename);
  }

  /// Extracts raw text page-by-page from a local PDF [File] using
  /// `PdfDocument` and `PdfTextExtractor`.
  Future<String> extractTextFromPdfFile(
    File file, {
    String filename = 'document.pdf',
  }) async {
    final bytes = await file.readAsBytes();
    return extractTextFromPdfBytes(bytes, filename: filename);
  }

  /// Extracts raw text page-by-page from raw PDF [bytes] using Syncfusion,
  /// applying dynamic cross-page repeating line frequency analysis to strip
  /// marginalia/headers/footers, UTF-8 character validation, vector/graphics
  /// stream exclusion, and grammar-aware line-unwrapping.
  String extractTextFromPdfBytes(
    Uint8List bytes, {
    String filename = 'document.pdf',
  }) {
    if (bytes.isEmpty) return '';

    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final pageTexts = <String>[];

      for (var i = 0; i < document.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i);
        if (pageText.trim().isNotEmpty) {
          pageTexts.add(pageText);
        }
      }

      document.dispose();

      if (pageTexts.isNotEmpty) {
        final sanitized = sanitizeExtractedPages(pageTexts);
        if (sanitized.isNotEmpty) {
          return sanitized;
        }
      }
    } on Object {
      // Fallback to byte stream extraction if PDF structure is non-standard
    }

    final fallbackText = _documentParserService.extractTextFromBytes(
      bytes,
      fileType: 'pdf',
      filename: filename,
    );

    return sanitizeExtractedText(fallbackText);
  }

  /// Dynamically sanitizes extracted pages by computing line occurrence frequency
  /// across pages to automatically identify and eliminate repeating headers,
  /// footers, watermarks, and marginalia without hardcoded rules.
  static String sanitizeExtractedPages(List<String> pages) {
    if (pages.isEmpty) return '';

    // 1. Compute line frequency across all pages to detect dynamic repeating headers/footers
    final linePageCounts = <String, int>{};
    final pageLinesList = <List<String>>[];

    for (final page in pages) {
      final lines = page.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      final seenOnThisPage = <String>{};

      for (final line in lines) {
        final normalized = _normalizeLineForFrequency(line);
        if (normalized.length >= 3 && !seenOnThisPage.contains(normalized)) {
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

    final collectedValidLines = <String>[];

    for (final lines in pageLinesList) {
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        final normalized = _normalizeLineForFrequency(trimmed);

        // Discard dynamically identified repeating marginalia/headers/footers
        if (repeatingMarginalia.contains(normalized)) {
          continue;
        }

        // Discard renderer metadata & dynamic page number patterns
        if (isMetadataOrRendererArtifact(trimmed)) {
          continue;
        }

        // Discard non-printable corrupted binary glyph noise (> 10% corrupted)
        if (isCorruptedBinaryNoise(trimmed)) {
          continue;
        }

        // Must satisfy general natural language / formula density threshold
        if (!DocumentParserService.isMeaningfulEducationalText(trimmed)) {
          continue;
        }

        // Strip standalone URLs and bullet symbols
        final clean = trimmed
            .replaceAll(RegExp(r'https?://\S+|www\.\S+'), '')
            .replaceAll(RegExp(r'^(?:[•\-–—*#]+\s*)'), '')
            .trim();

        if (clean.isNotEmpty) {
          collectedValidLines.add(clean);
        }
      }
    }

    return _unwrapContinuousLines(collectedValidLines);
  }

  /// Sanitizes raw single-block extracted text into coherent paragraphs.
  static String sanitizeExtractedText(String rawText) {
    if (rawText.isEmpty) return '';
    return sanitizeExtractedPages([rawText]);
  }

  static String _normalizeLineForFrequency(String line) {
    return line
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\d+'), '')
        .trim();
  }

  /// Grammar-aware line unwrapping: joins mid-sentence line breaks with single spaces
  /// while maintaining paragraph breaks after sentence terminators or structural headings.
  static String _unwrapContinuousLines(List<String> validLines) {
    if (validLines.isEmpty) return '';

    final buffer = StringBuffer();
    final headerRegex = RegExp(
      r'^(?:(?:Chapter|Section|Part|Step|Rule|Unit|Module|Topic)\s+[A-Z0-9\.]+|(?:\d+\.)+\d*|\b[IVXLCDM]+\.)\s*(.*)$|^[A-Z0-9\s\-_:]{3,45}$',
      caseSensitive: false,
    );

    for (var i = 0; i < validLines.length; i++) {
      final current = validLines[i];
      buffer.write(current);

      if (i < validLines.length - 1) {
        final next = validLines[i + 1];

        final isHeader = headerRegex.hasMatch(current) || current.endsWith(':');
        final nextIsHeader = headerRegex.hasMatch(next) || next.endsWith(':');

        final endsWithSentenceTerminator = current.endsWith('.') ||
            current.endsWith('?') ||
            current.endsWith('!') ||
            current.endsWith(':');

        if (isHeader || nextIsHeader || (endsWithSentenceTerminator && next.isNotEmpty && next[0].toUpperCase() == next[0])) {
          buffer.write('\n\n');
        } else {
          // Wrapped line mid-sentence -> join with single space
          buffer.write(' ');
        }
      }
    }

    return buffer.toString().trim();
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

  /// Parses a local PDF file and synthesizes structured flashcard snippets.
  Future<List<OcrExtractionModel>> parsePdfFileToFlashcards({
    required String documentId,
    required File file,
    required String filename,
    List<String> imageUrls = const [],
  }) async {
    final bytes = await file.readAsBytes();
    return parsePdfBytesToFlashcards(
      documentId: documentId,
      bytes: bytes,
      filename: filename,
      imageUrls: imageUrls,
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
}
