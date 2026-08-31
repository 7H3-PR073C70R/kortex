import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';

abstract class RagRepository {
  /// Executes semantic similarity vector search across indexed document chunks.
  Future<Either<Failure, List<DocumentChunkEntity>>> queryDocumentContext({
    required String query,
    double matchThreshold = 0.70,
    int matchCount = 3,
    String? documentId,
  });

  /// Triggers background vector indexing for an ingested document.
  Future<Either<Failure, int>> generateDocumentEmbeddings({
    required String documentId,
    required String rawText,
    Map<String, dynamic>? metadata,
  });
}
