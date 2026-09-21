import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Returns `true` when the app is running on an iOS Simulator.
///
/// Google ML Kit ships binary XCFrameworks that do not include an
/// `arm64-apple-ios-simulator` slice, which is required by iOS 26+ simulators
/// on Apple Silicon. Calling ML Kit on simulator would crash at the native
/// linker level; this guard lets callers degrade gracefully.
bool get _isIosSimulator =>
    !kIsWeb &&
    Platform.isIOS &&
    Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

/// Exception thrown when on-device OCR encounters an invalid document,
/// corrupted payload, or unreadable content.
class OcrProcessingException implements Exception {
  const OcrProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A data model mirroring an ML Kit text block with positional metadata,
/// kept stable for callers that relied on the previous interface.
class RecognizedTextBlock {
  const RecognizedTextBlock({
    required this.text,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.confidence = 0.95,
  });

  final String text;
  final double left;
  final double top;
  final double width;
  final double height;
  final double confidence;
}

/// Client that wraps `google_mlkit_text_recognition` for on-device image OCR.
///
/// Supports recognition via a file path (preferred) or raw bytes.
/// When only bytes are available, they are written to a temporary file
/// so that the native ML Kit API can process them.
///
/// **Platform support**: iOS and Android only (ML Kit limitation).
class LocalMlkitOcrClient {
  const LocalMlkitOcrClient();

  /// Recognizes text in an image, returning structured [RecognizedTextBlock]s.
  ///
  /// Provide [imagePath] whenever possible to avoid the temp-file write.
  /// Falls back to [bytes] → temp-file when [imagePath] is null or missing.
  Future<List<RecognizedTextBlock>> processImageBytes(
    Uint8List bytes, {
    String? imagePath,
  }) async {
    // ML Kit XCFrameworks do not include an arm64 simulator slice.
    // Return empty instead of crashing on iOS 26+ simulator.
    if (_isIosSimulator) return const [];

    if (bytes.isEmpty) {
      throw const OcrProcessingException(
        'Empty document payload. Please select a valid image.',
      );
    }

    final InputImage inputImage;

    if (imagePath != null && File(imagePath).existsSync()) {
      inputImage = InputImage.fromFilePath(imagePath);
    } else {
      // Write bytes to a temporary file so ML Kit can access them natively.
      final ext = _sniffExtension(bytes);
      final tmpDir = await getTemporaryDirectory();
      final tmpFile = File(
        '${tmpDir.path}/mlkit_ocr_${DateTime.now().microsecondsSinceEpoch}.$ext',
      );
      await tmpFile.writeAsBytes(bytes, flush: true);

      try {
        inputImage = InputImage.fromFilePath(tmpFile.path);
        final result = await _recognize(inputImage);
        return result;
      } finally {
        try {
          await tmpFile.delete();
        } on Object catch (_) {}
      }
    }

    return _recognize(inputImage);
  }

  Future<List<RecognizedTextBlock>> _recognize(InputImage inputImage) async {
    final recognizer = TextRecognizer();
    try {
      final recognized = await recognizer.processImage(inputImage);

      if (recognized.text.trim().isEmpty) {
        throw const OcrProcessingException(
          'No legible text could be recognized in this image. '
          'Please ensure the document is clear, well-lit, and properly oriented.',
        );
      }

      final blocks = <RecognizedTextBlock>[];
      for (final block in recognized.blocks) {
        final rect = block.boundingBox;
        blocks.add(
          RecognizedTextBlock(
            text: block.text,
            left: rect.left,
            top: rect.top,
            width: rect.width,
            height: rect.height,
            // ML Kit does not expose per-block confidence — default (0.95) is used.
          ),
        );
      }

      return blocks;
    } finally {
      await recognizer.close();
    }
  }

  /// Sniffs the image magic bytes to pick an appropriate temp-file extension.
  static String _sniffExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return 'png'; // safe default
  }
}
