import 'dart:typed_data';

class OcrProcessingException implements Exception {
  const OcrProcessingException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

class LocalMlkitOcrClient {
  const LocalMlkitOcrClient();

  Future<List<RecognizedTextBlock>> processImageBytes(
    Uint8List bytes, {
    String? imagePath,
  }) async {
    throw const OcrProcessingException(
      'On-device ML Kit OCR is only available on iOS and Android.',
    );
  }
}
