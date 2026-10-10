import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_image_ocr_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pptx_parser_service.dart';
import 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

export 'package:kortex/src/features/ingestion/domain/exceptions/ingestion_exceptions.dart';

/// Central client-side text extraction service for Kortexify.
///
/// Handles PDF, PPTX, plain text, and images (via on-device ML Kit OCR)
/// in background operations, normalizing outputs into a unified text stream.
/// Heavy synthesis work (flashcard generation) is handled entirely server-side.
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
  ///
  /// Image types (png, jpg, jpeg, webp) are processed via on-device Google ML Kit OCR.
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
          rawExtractedText = await _pdfParser.extractText(
            bytes,
            filename: filePath ?? 'document.pdf',
          );

        case 'pptx':
          rawExtractedText = await _pptxParser.extractText(bytes);

        case 'docx':
        case 'epub':
        case 'html':
        case 'htm':
        case 'tex':
        case 'latex':
          rawExtractedText = _documentParser.extractTextFromBytes(
            bytes,
            fileType: ext,
            filename: filePath ?? 'document.$ext',
          );

        case 'png':
        case 'jpg':
        case 'jpeg':
        case 'webp':
          // On-device ML Kit OCR — runs natively on iOS/Android.
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
      if (e is FileSizeExceededException ||
          e is UnsupportedFileTypeException ||
          e is EncryptedPdfException ||
          e is CorruptDocumentException ||
          e is ScannedDocumentException) {
        rethrow;
      }
      throw DocumentExtractionException('Extraction failed for .$ext: $e');
    }

    // Normalize and sanitize text buffer in background isolate
    return compute(normalizeTextBuffer, rawExtractedText);
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

    // 3. Code & math-safe line processing
    final lines = cleaned.split('\n');
    final processedLines = <String>[];
    var inCode = false;
    var inMath = false;
    String? codeFence;

    for (final line in lines) {
      final trimmed = line.trim();

      // Check code fences
      if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
        final fence = trimmed.substring(0, 3);
        if (!inCode) {
          inCode = true;
          codeFence = fence;
        } else if (fence == codeFence) {
          inCode = false;
          codeFence = null;
        }
        processedLines.add(line);
        continue;
      }
      if (inCode) {
        processedLines.add(line);
        continue;
      }

      // Check math delimiters
      if (trimmed.startsWith(r'$$') || trimmed.startsWith(r'\[')) {
        if (!inMath) {
          inMath = true;
          if (trimmed.length > 2 && (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]'))) {
            inMath = false;
          }
        } else {
          inMath = false;
        }
        processedLines.add(line);
        continue;
      }
      if (trimmed.startsWith(r'\begin{')) {
        inMath = true;
        processedLines.add(line);
        continue;
      }
      if (inMath) {
        if (trimmed.endsWith(r'$$') || trimmed.endsWith(r'\]') || trimmed.startsWith(r'\end{')) {
          inMath = false;
        }
        processedLines.add(line);
        continue;
      }

      // Filter out isolated footer page numbers like "Page 1 of 12" or single standalone numbers
      if (RegExp(
        r'^(page\s+\d+(\s+of\s+\d+)?|\d+)$',
        caseSensitive: false,
      ).hasMatch(trimmed)) {
        continue;
      }

      // Remove separator lines outside code
      if (RegExp(r'^[-_=~*]{4,}$').hasMatch(trimmed)) {
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
