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
  /// applying strict UTF-8 character validation, vector/graphics stream
  /// exclusion, and PDF generator metadata filtering.
  String extractTextFromPdfBytes(
    Uint8List bytes, {
    String filename = 'document.pdf',
  }) {
    if (bytes.isEmpty) return '';

    try {
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);
      final buffer = StringBuffer();

      for (var i = 0; i < document.pages.count; i++) {
        final pageText = extractor.extractText(startPageIndex: i);
        final sanitizedPageText = sanitizeExtractedText(pageText);
        if (sanitizedPageText.isNotEmpty) {
          buffer.writeln(sanitizedPageText);
        }
      }

      document.dispose();

      final extracted = buffer.toString().trim();
      if (extracted.isNotEmpty) {
        return extracted;
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

  /// Sanitizes raw extracted text by filtering out non-printable binary
  /// corruption, control character noise, and PDF generator/renderer metadata.
  static String sanitizeExtractedText(String rawText) {
    if (rawText.isEmpty) return '';

    final lines = rawText.split('\n');
    final cleanLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // 1. Filter out renderer metadata & watermarks
      if (isMetadataOrRendererArtifact(trimmed)) {
        continue;
      }

      // 2. Strict UTF-8 & printable character validation (> 10% corrupted -> discard)
      if (isCorruptedBinaryNoise(trimmed)) {
        continue;
      }

      cleanLines.add(trimmed);
    }

    return cleanLines.join('\n');
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

      // Common valid Unicode text & symbol blocks:
      // - Latin-1 Supplement (160-255: letters, accents, math symbols)
      // - Latin Extended-A & B (256-591)
      // - Greek & Coptic (0x0370 - 0x03FF)
      // - General Punctuation (0x2000 - 0x206F: quotes, dashes, bullets)
      // - Currency Symbols (0x20A0 - 0x20CF)
      // - Letterlike Symbols & Number Forms (0x2100 - 0x218F)
      // - Mathematical Operators (0x2200 - 0x22FF)
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

      // Any other exotic/unrecognized high bytes in non-CJK documents are counted as invalid
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

  /// Filters out incidental PDF generator metadata or renderer strings.
  static bool isMetadataOrRendererArtifact(String line) {
    final lower = line.toLowerCase();

    final metadataPatterns = [
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
      'aapl:keywords',
      'ptx.fullbanner',
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

    for (final pattern in metadataPatterns) {
      if (lower.contains(pattern)) {
        return true;
      }
    }

    // Page numbering artifacts like "Page 1 of 12" or "1 / 15"
    if (RegExp(
      r'^(page\s+\d+(\s+of\s+\d+)?|\d+\s*/\s*\d+|\d+)$',
      caseSensitive: false,
    ).hasMatch(line)) {
      return true;
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
