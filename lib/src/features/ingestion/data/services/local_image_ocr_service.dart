import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Service responsible for offline mobile image OCR directly from pixels.
class LocalImageOcrService {
  LocalImageOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Extracts text from an image file path offline.
  Future<String> extractTextFromPath(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Image file not found at path: $filePath');
    }

    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      return _normalizeRecognizedText(recognizedText);
    } catch (e) {
      if (kDebugMode) {
        print('[LocalImageOcrService] Error recognizing text from path: $e');
      }
      throw Exception('Failed to perform offline OCR on image: $e');
    }
  }

  /// Extracts text from image bytes offline by saving to a temporary buffer file.
  Future<String> extractTextFromBytes(Uint8List bytes, {String extension = 'png'}) async {
    if (bytes.isEmpty) return '';

    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/ocr_temp_${DateTime.now().microsecondsSinceEpoch}.$extension';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes, flush: true);

      final result = await extractTextFromPath(tempPath);
      return result;
    } catch (e) {
      if (kDebugMode) {
        print('[LocalImageOcrService] Error recognizing text from bytes: $e');
      }
      // Return empty or throw based on severity
      return '';
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Organizes recognized blocks in top-to-bottom reading order and formats paragraphs.
  String _normalizeRecognizedText(RecognizedText recognizedText) {
    final blocks = recognizedText.blocks;
    if (blocks.isEmpty) return '';

    // Sort blocks top-to-bottom, left-to-right
    final sortedBlocks = List<TextBlock>.from(blocks)
      ..sort((a, b) {
        final topDiff = a.boundingBox.top.compareTo(b.boundingBox.top);
        if (topDiff.abs() > 20) return topDiff;
        return a.boundingBox.left.compareTo(b.boundingBox.left);
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

  /// Disposes the native ML Kit text recognizer resources.
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
