/// Domain entity representing a recognized bounding box of text from OCR.
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
