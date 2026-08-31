import 'package:equatable/equatable.dart';

/// Domain entity representing an extracted STEM snippet with LaTeX formulas.
class OcrExtractionEntity extends Equatable {
  const OcrExtractionEntity({
    required this.id,
    required this.documentId,
    required this.rawText,
    this.latexContent,
    this.topic = 'General',
    this.confidenceScore = 0.95,
  });

  final String id;
  final String documentId;
  final String rawText;
  final String? latexContent;
  final String topic;
  final double confidenceScore;

  OcrExtractionEntity copyWith({
    String? id,
    String? documentId,
    String? rawText,
    String? latexContent,
    String? topic,
    double? confidenceScore,
  }) {
    return OcrExtractionEntity(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      rawText: rawText ?? this.rawText,
      latexContent: latexContent ?? this.latexContent,
      topic: topic ?? this.topic,
      confidenceScore: confidenceScore ?? this.confidenceScore,
    );
  }

  @override
  List<Object?> get props => [
        id,
        documentId,
        rawText,
        latexContent,
        topic,
        confidenceScore,
      ];
}
