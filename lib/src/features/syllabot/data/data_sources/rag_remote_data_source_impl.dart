import 'package:kortex/src/features/syllabot/data/client/vector_search_client.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/rag_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/data/models/document_chunk_model.dart';

class RagRemoteDataSourceImpl implements RagRemoteDataSource {
  RagRemoteDataSourceImpl(this._client);

  final VectorSearchClient _client;

  @override
  Future<List<DocumentChunkModel>> queryDocumentContext({
    required String query,
    required double matchThreshold,
    required int matchCount,
    String? documentId,
  }) async {
    final list = await _client.matchDocumentChunks(
      query: query,
      matchThreshold: matchThreshold,
      matchCount: matchCount,
      documentId: documentId,
    );

    return list.map(DocumentChunkModel.fromJson).toList();
  }

  /// Maximum chunks dispatched per HTTP call to the generate-embeddings edge function.
  /// Prevents Deno isolate memory & compute spikes (WORKER_RESOURCE_LIMIT / 546) on large textbooks.
  static const int maxBatchSize = 25;

  @override
  Future<int> generateDocumentEmbeddings({
    required String documentId,
    String? rawText,
    List<Map<String, dynamic>>? chunks,
    Map<String, dynamic>? metadata,
  }) async {
    if (chunks != null && chunks.length > maxBatchSize) {
      var totalCreated = 0;
      for (var i = 0; i < chunks.length; i += maxBatchSize) {
        final end = (i + maxBatchSize < chunks.length)
            ? i + maxBatchSize
            : chunks.length;
        final batch = chunks.sublist(i, end);
        final res = await _client.generateEmbeddings(
          documentId: documentId,
          chunks: batch,
          metadata: metadata,
        );
        totalCreated +=
            (res['chunks_created'] as num?)?.toInt() ?? batch.length;
      }
      return totalCreated;
    }

    final res = await _client.generateEmbeddings(
      documentId: documentId,
      rawText: (chunks != null && chunks.isNotEmpty) ? null : rawText,
      chunks: chunks,
      metadata: metadata,
    );

    return (res['chunks_created'] as num?)?.toInt() ?? chunks?.length ?? 1;
  }
}
