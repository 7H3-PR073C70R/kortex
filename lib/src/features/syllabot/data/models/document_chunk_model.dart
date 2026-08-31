import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';

class DocumentChunkModel extends DocumentChunkEntity {
  const DocumentChunkModel({
    required super.id,
    required super.documentId,
    required super.content,
    required super.similarityScore,
    super.metadata = const {},
    super.documentTitle,
    super.pageNumber,
  });

  factory DocumentChunkModel.fromJson(Map<String, dynamic> json) {
    final meta = (json['metadata'] as Map<String, dynamic>?) ?? {};
    return DocumentChunkModel(
      id: json['id'] as String? ?? '',
      documentId: json['document_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      similarityScore: (json['similarity'] as num?)?.toDouble() ??
          (json['similarity_score'] as num?)?.toDouble() ??
          0.85,
      metadata: meta,
      documentTitle: json['document_title'] as String? ??
          meta['document_title'] as String?,
      pageNumber: (json['page_number'] as num?)?.toInt() ??
          (meta['page_number'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'content': content,
      'similarity': similarityScore,
      'metadata': metadata,
      'document_title': documentTitle,
      'page_number': pageNumber,
    };
  }

  DocumentChunkEntity toEntity() => this;
}
