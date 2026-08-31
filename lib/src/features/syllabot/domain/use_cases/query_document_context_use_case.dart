import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';

/// Fetches top-k semantically relevant course document snippets for a prompt.
class QueryDocumentContextUseCase {
  const QueryDocumentContextUseCase(this._repository);

  final RagRepository _repository;

  Future<Either<Failure, List<DocumentChunkEntity>>> call({
    required String query,
    double matchThreshold = 0.65,
    int matchCount = 3,
    String? documentId,
  }) {
    return _repository.queryDocumentContext(
      query: query,
      matchThreshold: matchThreshold,
      matchCount: matchCount,
      documentId: documentId,
    );
  }
}
