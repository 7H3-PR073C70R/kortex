import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_image_ocr_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pptx_parser_service.dart';

/// Custom exceptions for local document ingestion
class FileSizeExceededException implements Exception {
  const FileSizeExceededException([
    this.message = 'File exceeds maximum 50MB limit',
  ]);
  final String message;
  @override
  String toString() => 'FileSizeExceededException: $message';
}

class UnsupportedFileTypeException implements Exception {
  const UnsupportedFileTypeException(this.extension);
  final String extension;
  @override
  String toString() =>
      'UnsupportedFileTypeException: File type ".$extension" is not supported';
}

class DocumentExtractionException implements Exception {
  const DocumentExtractionException(this.message);
  final String message;
  @override
  String toString() => 'DocumentExtractionException: $message';
}

/// Central offline document ingestion and OCR routing service for Kortexify.
///
/// Handles PDF, PPTX, PNG, JPG, and text files entirely offline in background
/// isolates, normalizing outputs into a unified text stream for local LLM synthesis.
class LocalIngestionService {
  LocalIngestionService({
    LocalPdfParserService? pdfParser,
    LocalPptxParserService? pptxParser,
    LocalImageOcrService? imageOcr,
    DocumentParserService? documentParser,
  }) : _pdfParser = pdfParser ?? const LocalPdfParserService(),
       _pptxParser = pptxParser ?? const LocalPptxParserService(),
       _imageOcr = imageOcr ?? LocalImageOcrService(),
       _documentParser = documentParser ?? const DocumentParserService();

  final LocalPdfParserService _pdfParser;
  final LocalPptxParserService _pptxParser;
  final LocalImageOcrService _imageOcr;
  final DocumentParserService _documentParser;

  /// Maximum file size limit for local ingestion: 50MB
  static const int maxFileSizeInBytes = 50 * 1024 * 1024;

  /// Ingests a file from disk, enforcing size limits and routing to its format extractor.
  Future<String> ingestFile(File file) async {
    if (!file.existsSync()) {
      throw DocumentExtractionException('File does not exist: ${file.path}');
    }

    final length = await file.length();
    if (length > maxFileSizeInBytes) {
      throw FileSizeExceededException(
        'File size of ${(length / (1024 * 1024)).toStringAsFixed(1)}MB exceeds maximum 50MB limit.',
      );
    }

    final extension = _extractExtension(file.path);
    final bytes = await file.readAsBytes();

    return ingestBytes(
      bytes: bytes,
      extension: extension,
      filePath: file.path,
    );
  }

  /// Ingests binary bytes, enforces 50MB limit, routes by extension, and normalizes text.
  Future<String> ingestBytes({
    required Uint8List bytes,
    required String extension,
    String? filePath,
  }) async {
    if (bytes.length > maxFileSizeInBytes) {
      throw FileSizeExceededException(
        'Document of ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB exceeds 50MB limit.',
      );
    }

    final ext = extension.toLowerCase().replaceAll('.', '').trim();
    String rawExtractedText;

    try {
      switch (ext) {
        case 'pdf':
          rawExtractedText = await _pdfParser.extractText(bytes);

        case 'pptx':
          rawExtractedText = await _pptxParser.extractText(bytes);

        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'webp':
          if (filePath != null && File(filePath).existsSync()) {
            rawExtractedText = await _imageOcr.extractTextFromPath(filePath);
          } else {
            rawExtractedText = await _imageOcr.extractTextFromBytes(
              bytes,
              extension: ext,
            );
          }

        case 'txt':
        case 'md':
        case 'markdown':
          rawExtractedText = utf8.decode(bytes, allowMalformed: true);

        default:
          throw UnsupportedFileTypeException(ext);
      }
    } catch (e) {
      if (e is UnsupportedFileTypeException || e is FileSizeExceededException) {
        rethrow;
      }
      throw DocumentExtractionException('Extraction failed for .$ext: $e');
    }

    // Normalize and sanitize text buffer in background isolate
    return compute(normalizeTextBuffer, rawExtractedText);
  }

  /// Synthesizes structured flashcards directly from ingested document text offline.
  DeckEntity synthesizeFlashcardsLocally({
    required String normalizedText,
    required String title,
    String? documentId,
    String courseCode = 'GEN101',
    String filename = 'document.txt',
  }) {
    final docId =
        documentId ?? 'doc_local_${DateTime.now().millisecondsSinceEpoch}';
    final snippets = _documentParser.synthesizeSnippetsFromDocument(
      documentId: docId,
      fullText: normalizedText,
      filename: filename,
    );

    final cards = <FlashcardEntity>[];
    for (var i = 0; i < snippets.length; i++) {
      final s = snippets[i];
      cards.add(
        FlashcardEntity(
          id: 'card_${docId}_$i',
          deckId: docId,
          front: s.topic.isNotEmpty ? s.topic : 'Key Concept ${i + 1}',
          back: s.rawText,
          backLatex: s.latexContent,
          imageUrl: s.imageUrl,
          sourceTopic: s.topic,
          nextDueDate: DateTime.now().add(const Duration(days: 1)),
        ),
      );
    }

    return DeckEntity(
      id: docId,
      title: title,
      subject: courseCode,
      totalCards: cards.length,
      dueCards: cards.length,
      masteryRate: 0,
      category: 'Document Ingestion',
      description: 'Auto-synthesized locally from document $docId',
      cards: cards,
    );
  }

  /// Cleans, normalizes, and strips layout noise, excessive whitespace, and non-printable characters.
  static String normalizeTextBuffer(String rawText) {
    if (rawText.trim().isEmpty) return '';

    // 1. Remove non-printable control characters (except newlines and tabs)
    var cleaned = rawText.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      '',
    );

    // 2. Normalize carriage returns
    cleaned = cleaned.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // 3. Remove repeating separator lines or underline clutter
    cleaned = cleaned.replaceAll(RegExp('[-_=~*]{4,}'), '');

    // 4. Strip excessive blank lines (more than 2 consecutive newlines)
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // 5. Clean trailing and leading spaces per line
    final lines = cleaned.split('\n');
    final processedLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      // Filter out isolated footer page numbers like "Page 1 of 12" or single standalone numbers
      if (RegExp(
        r'^(page\s+\d+(\s+of\s+\d+)?|\d+)$',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        continue;
      }
      processedLines.add(trimmed);
    }

    return processedLines.join('\n').trim();
  }

  String _extractExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex + 1);
  }
}
