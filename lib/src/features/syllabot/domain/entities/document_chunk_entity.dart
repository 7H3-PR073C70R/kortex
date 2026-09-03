import 'package:equatable/equatable.dart';

/// Represents a semantically indexed course document chunk
/// with similarity score.
class DocumentChunkEntity extends Equatable {
  const DocumentChunkEntity({
    required this.id,
    required this.documentId,
    required this.content,
    required this.similarityScore,
    this.metadata = const {},
    this.documentTitle,
    this.pageNumber,
  });

  final String id;
  final String documentId;
  final String content;
  final double similarityScore; // 0.0 to 1.0
  final Map<String, dynamic> metadata;
  final String? documentTitle;
  final int? pageNumber;

  @override
  List<Object?> get props => [
    id,
    documentId,
    content,
    similarityScore,
    metadata,
    documentTitle,
    pageNumber,
  ];
}
