import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/ingestion/domain/entities/recognized_text_block.dart';

class OcrProcessingException implements Exception {
  const OcrProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalMlkitOcrClient {
  const LocalMlkitOcrClient();

  Future<List<RecognizedTextBlock>> processImageBytes(
    Uint8List bytes, {
    String? imagePath,
  }) async {
    if (bytes.isEmpty) return const [];
    return const [];
  }
}
