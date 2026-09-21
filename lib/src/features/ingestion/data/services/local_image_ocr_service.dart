import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';

/// Service responsible for on-device image OCR using Google ML Kit.
///
/// Wraps [LocalMlkitOcrClient] with top-to-bottom reading-order normalization
/// and error handling, exposing a simple string-output interface for the
/// ingestion pipeline.
///
/// **Platform support**: iOS and Android only.
class LocalImageOcrService {
  LocalImageOcrService({LocalMlkitOcrClient? ocrClient})
    : _ocrClient = ocrClient ?? const LocalMlkitOcrClient();

  final LocalMlkitOcrClient _ocrClient;

  /// Extracts text from an image at [filePath] using on-device ML Kit OCR.
  Future<String> extractTextFromPath(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Image file not found at path: $filePath');
    }

    try {
      final bytes = await file.readAsBytes();
      return _processWithClient(bytes, imagePath: filePath);
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[LocalImageOcrService] Error from path: $e');
      }
      throw Exception('Failed to perform on-device OCR on image: $e');
    }
  }

  /// Extracts text from raw image [bytes] using on-device ML Kit OCR.
  ///
  /// Optionally provide [imagePath] to skip a temp-file write inside the client.
  Future<String> extractTextFromBytes(
    Uint8List bytes, {
    String? imagePath,
    String extension = 'png',
  }) async {
    if (bytes.isEmpty) return '';

    try {
      return _processWithClient(bytes, imagePath: imagePath);
    } on Object catch (e) {
      if (kDebugMode) {
        debugPrint('[LocalImageOcrService] Error from bytes: $e');
      }
      return '';
    }
  }

  Future<String> _processWithClient(
    Uint8List bytes, {
    String? imagePath,
  }) async {
    try {
      final blocks = await _ocrClient.processImageBytes(
        bytes,
        imagePath: imagePath,
      );
      return _normalizeBlocks(blocks);
    } on OcrProcessingException {
      return '';
    }
  }

  /// Sorts recognized blocks top-to-bottom, left-to-right and joins them.
  String _normalizeBlocks(List<RecognizedTextBlock> blocks) {
    if (blocks.isEmpty) return '';

    final sorted = List<RecognizedTextBlock>.from(blocks)
      ..sort((a, b) {
        final topDiff = a.top.compareTo(b.top);
        if (topDiff.abs() > 20) return topDiff;
        return a.left.compareTo(b.left);
      });

    final buffer = StringBuffer();
    for (final block in sorted) {
      final text = block.text.trim();
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln('\n');
        buffer.write(text);
      }
    }

    return buffer.toString().trim();
  }

  /// Disposes resources. No-op since the recognizer is closed per-call.
  Future<void> dispose() async {}
}
