import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';

/// Service responsible for offline mobile image OCR directly from pixels.
class LocalImageOcrService {
  LocalImageOcrService({LocalMlkitOcrClient? ocrClient})
    : _ocrClient = ocrClient ?? const LocalMlkitOcrClient();

  final LocalMlkitOcrClient _ocrClient;

  /// Extracts text from an image file path offline.
  Future<String> extractTextFromPath(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Image file not found at path: $filePath');
    }

    try {
      final bytes = await file.readAsBytes();
      return extractTextFromBytes(bytes);
    } on Object catch (e) {
      if (kDebugMode) {
        print('[LocalImageOcrService] Error recognizing text from path: $e');
      }
      throw Exception('Failed to perform offline OCR on image: $e');
    }
  }

  /// Extracts text from image bytes offline using local on-device OCR.
  Future<String> extractTextFromBytes(
    Uint8List bytes, {
    String extension = 'png',
  }) async {
    if (bytes.isEmpty) return '';

    try {
      final blocks = await _ocrClient.processImageBytes(bytes);
      return _normalizeRecognizedBlocks(blocks);
    } on Object catch (e) {
      if (kDebugMode) {
        print('[LocalImageOcrService] Error recognizing text from bytes: $e');
      }
      return '';
    }
  }

  /// Organizes recognized blocks in top-to-bottom reading order and formats paragraphs.
  String _normalizeRecognizedBlocks(List<RecognizedTextBlock> blocks) {
    if (blocks.isEmpty) return '';

    // Sort blocks top-to-bottom, left-to-right
    final sortedBlocks = List<RecognizedTextBlock>.from(blocks)
      ..sort((a, b) {
        final topDiff = a.top.compareTo(b.top);
        if (topDiff.abs() > 20) return topDiff;
        return a.left.compareTo(b.left);
      });

    final buffer = StringBuffer();
    for (final block in sortedBlocks) {
      final text = block.text.trim();
      if (text.isNotEmpty) {
        if (buffer.isNotEmpty) buffer.writeln('\n');
        buffer.write(text);
      }
    }

    return buffer.toString().trim();
  }

  /// Disposes resources.
  Future<void> dispose() async {}
}
