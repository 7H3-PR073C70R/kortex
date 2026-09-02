import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

class OcrExtractionModel {
  const OcrExtractionModel({
    required this.id,
    required this.documentId,
    required this.rawText,
    this.latexContent,
    this.imageUrl,
    this.topic = 'General',
    this.confidenceScore = 0.95,
  });

  final String id;
  final String documentId;
  final String rawText;
  final String? latexContent;
  final String? imageUrl;
  final String topic;
  final double confidenceScore;

  factory OcrExtractionModel.fromJson(Map<String, dynamic> json) {
    return OcrExtractionModel(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      rawText: json['raw_text'] as String,
      latexContent: json['latex_content'] as String?,
      imageUrl: json['image_url'] as String?,
      topic: json['topic'] as String? ?? 'General',
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.95,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'raw_text': rawText,
      'latex_content': latexContent,
      if (imageUrl != null) 'image_url': imageUrl,
      'topic': topic,
      'confidence_score': confidenceScore,
    };
  }

  OcrExtractionEntity toEntity() {
    return OcrExtractionEntity(
      id: id,
      documentId: documentId,
      rawText: rawText,
      latexContent: latexContent,
      imageUrl: imageUrl,
      topic: topic,
      confidenceScore: confidenceScore,
    );
  }

  static OcrExtractionModel fromEntity(OcrExtractionEntity entity) {
    return OcrExtractionModel(
      id: entity.id,
      documentId: entity.documentId,
      rawText: entity.rawText,
      latexContent: entity.latexContent,
      imageUrl: entity.imageUrl,
      topic: entity.topic,
      confidenceScore: entity.confidenceScore,
    );
  }
}
