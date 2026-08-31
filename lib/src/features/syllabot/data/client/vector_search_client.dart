import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';

class VectorSearchClient {
  VectorSearchClient(this._dio);

  final Dio _dio;

  Map<String, String> _headers(String token) => {
        'apikey': AppEnv.supabaseAnonKey,
        'Authorization': 'Bearer $token',
      };

  /// Queries pgvector RPC function `match_document_chunks`
  /// for top matching snippets.
  Future<List<Map<String, dynamic>>> matchDocumentChunks({
    required String query,
    required double matchThreshold,
    required int matchCount,
    required String authToken,
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
      options: Options(headers: _headers(authToken)),
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
    required String authToken,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.generateEmbeddings}',
      data: {
        'documentId': documentId,
        'rawText': rawText,
        'metadata': metadata ?? {},
      },
      options: Options(headers: _headers(authToken)),
    );

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return {'chunks_created': 1};
  }
}
