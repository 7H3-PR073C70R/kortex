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

  /// Extracts raw text page-by-page from raw PDF [bytes] using Syncfusion.
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
        if (pageText.trim().isNotEmpty) {
          buffer.writeln(pageText.trim());
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

    return _documentParserService.extractTextFromBytes(
      bytes,
      fileType: 'pdf',
      filename: filename,
    );
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
