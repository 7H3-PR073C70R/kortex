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

  @override
  Future<int> generateDocumentEmbeddings({
    required String documentId,
    String? rawText,
    List<Map<String, dynamic>>? chunks,
    Map<String, dynamic>? metadata,
  }) async {
    final res = await _client.generateEmbeddings(
      documentId: documentId,
      rawText: rawText,
      chunks: chunks,
      metadata: metadata,
    );

    return (res['chunks_created'] as num?)?.toInt() ?? chunks?.length ?? 1;
  }
}
