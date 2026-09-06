import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';

/// Dispatches raw document text to generate embeddings and index chunks into pgvector.
class GenerateDocumentEmbeddingsUseCase {
  const GenerateDocumentEmbeddingsUseCase(this._repository);

  final RagRepository _repository;

  Future<Either<Failure, int>> call({
    required String documentId,
    required String rawText,
    Map<String, dynamic>? metadata,
  }) {
    return _repository.generateDocumentEmbeddings(
      documentId: documentId,
      rawText: rawText,
      metadata: metadata,
    );
  }
}
