import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/rag_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/domain/entities/document_chunk_entity.dart';
import 'package:kortex/src/features/syllabot/domain/repositories/rag_repository.dart';

class RagRepositoryImpl implements RagRepository {
  RagRepositoryImpl(this._remoteDataSource);

  final RagRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<DocumentChunkEntity>>> queryDocumentContext({
    required String query,
    double matchThreshold = 0.70,
    int matchCount = 3,
    String? documentId,
  }) async {
    try {
      final models = await _remoteDataSource.queryDocumentContext(
        query: query,
        matchThreshold: matchThreshold,
        matchCount: matchCount,
        documentId: documentId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> generateDocumentEmbeddings({
    required String documentId,
    required String rawText,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final chunksCount = await _remoteDataSource.generateDocumentEmbeddings(
        documentId: documentId,
        rawText: rawText,
        metadata: metadata,
      );
      return Right(chunksCount);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
