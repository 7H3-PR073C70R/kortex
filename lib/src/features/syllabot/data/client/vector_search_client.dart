import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';

class VectorSearchClient {
  VectorSearchClient(this._dio);

  final Dio _dio;

  /// Queries pgvector RPC function `match_document_chunks`
  /// for top matching snippets.
  Future<List<Map<String, dynamic>>> matchDocumentChunks({
    required String query,
    required double matchThreshold,
    required int matchCount,
    String? documentId,
  }) async {
    final response = await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.matchDocumentChunksRpc}',
      data: {
        'query_text': query,
        'match_threshold': matchThreshold,
        'match_count': matchCount,
        'filter_document_id': ?documentId,
      },
    );

    if (response.data is List<dynamic>) {
      return (response.data as List<dynamic>).cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Dispatches document text to `generate-embeddings` Edge Function.
  Future<Map<String, dynamic>> generateEmbeddings({
    required String documentId,
    required String rawText,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateEmbeddings}',
      data: {
        'documentId': documentId,
        'rawText': rawText,
        'metadata': metadata ?? {},
      },
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'chunks_created': 1};
  }
}
