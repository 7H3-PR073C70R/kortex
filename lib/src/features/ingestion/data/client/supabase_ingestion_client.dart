import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';

/// Supabase Storage & PostgREST client for document ingestion and STEM OCR.
class SupabaseIngestionClient {
  SupabaseIngestionClient(this._dio);

  final Dio _dio;

  /// Checks system-wide for existing document with same content hash.
  /// If found, creates a personalized instance/reference in the user's folder
  /// and automatically clones/assigns the extracted snippets and cards to them.
  Future<Map<String, dynamic>?> findOrCreateDocumentReference({
    required String contentHash,
    required String filename,
    required String fileType,
    required int fileSizeBytes,
    required String authToken,
  }) async {
    final endpoint =
        '${AppApiEndpoint.baseUri}'
        '${AppApiEndpoint.findOrCreateDocumentReference}';
    final response = await _dio.post<dynamic>(
      endpoint,
      data: {
        'p_content_hash': contentHash,
        'p_filename': filename,
        'p_file_type': fileType,
        'p_file_size_bytes': fileSizeBytes,
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    final data = response.data;
    if (data != null && data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  /// Checks if a document with the same content SHA-256 hash already exists.
  Future<Map<String, dynamic>?> findDocumentByHash({
    required String contentHash,
    required String authToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.documents}',
      queryParameters: {
        'select': '*',
        'content_hash': 'eq.$contentHash',
        'limit': 1,
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    final data = response.data;
    if (data != null && data.isNotEmpty) {
      return data.first as Map<String, dynamic>;
    }
    return null;
  }

  /// Uploads binary file bytes directly to Supabase Storage bucket.
  Future<void> uploadStorageFile({
    required String storagePath,
    required Uint8List fileBytes,
    required String contentType,
    required String authToken,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.storageBucket}/$storagePath',
      data: fileBytes,
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
          'Content-Type': contentType,
          'x-upsert': 'true',
        },
      ),
      onSendProgress: onProgress,
    );
  }

  /// Registers document metadata record in `documents` table.
  Future<Map<String, dynamic>> createDocumentRecord({
    required String filename,
    required String fileType,
    required int fileSizeBytes,
    required String storagePath,
    required String contentHash,
    required String authToken,
  }) async {
    final response = await _dio.post<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.documents}',
      data: {
        'filename': filename,
        'file_type': fileType,
        'file_size_bytes': fileSizeBytes,
        'storage_path': storagePath,
        'content_hash': contentHash,
        'processing_status': 'uploaded',
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
          'Prefer': 'return=representation',
        },
      ),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw Exception('Failed to insert document record');
    }
    return data.first as Map<String, dynamic>;
  }

  /// Triggers the `parse-stem-ocr` Edge Function.
  Future<Map<String, dynamic>> triggerParseStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
    required String authToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.parseStemOcr}',
      data: {
        'documentId': documentId,
        'storagePath': storagePath,
        'fileType': fileType,
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return response.data ?? {};
  }

  /// Fetches parsed STEM snippets for a document.
  Future<List<Map<String, dynamic>>> fetchExtractedSnippets({
    required String documentId,
    required String authToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.extractedSnippets}',
      queryParameters: {
        'select': '*',
        'document_id': 'eq.$documentId',
        'order': 'created_at.asc',
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }

  /// Fetches all documents for the authenticated user.
  Future<List<Map<String, dynamic>>> fetchUserDocuments(
    String authToken,
  ) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.documents}',
      queryParameters: {
        'select': '*',
        'order': 'created_at.desc',
      },
      options: Options(
        headers: {
          'apikey': AppEnv.supabaseAnonKey,
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }
}
