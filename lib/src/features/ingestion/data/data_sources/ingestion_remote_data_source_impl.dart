import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:kortex/src/features/ingestion/data/client/ingestion_api_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/models/document_upload_model.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';

class IngestionRemoteDataSourceImpl implements IngestionRemoteDataSource {
  IngestionRemoteDataSourceImpl(this._client, this._dio);

  final IngestionApiClient _client;
  final Dio _dio;

  @override
  Future<DocumentUploadModel?> findOrCreateDocumentReference({
    required String contentHash,
    required String filename,
    required String fileType,
    required int fileSizeBytes,
  }) async {
    final res = await _client.findOrCreateDocumentReference(
      {
        'p_content_hash': contentHash,
        'p_filename': filename,
        'p_file_type': fileType,
        'p_file_size_bytes': fileSizeBytes,
      },
    );
    final data = res.data;
    if (data is Map<String, dynamic> && data['document'] != null) {
      final docMap = data['document'] as Map<String, dynamic>;
      final isDeduplicated = data['is_deduplicated'] as bool? ?? true;
      return DocumentUploadModel.fromJson(
        docMap,
        isDeduplicated: isDeduplicated,
      );
    }
    return null;
  }

  @override
  Future<DocumentUploadModel?> findDocumentByHash(String contentHash) async {
    final res = await _client.fetchDocuments(
      {
        'select': '*',
        'content_hash': 'eq.$contentHash',
        'limit': '1',
      },
    );
    final list = res.data is List ? (res.data as List) : <dynamic>[];
    if (list.isNotEmpty) {
      return DocumentUploadModel.fromJson(
        list.first as Map<String, dynamic>,
        isDeduplicated: true,
      );
    }
    return null;
  }

  @override
  Future<DocumentUploadModel> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    required String contentHash,
    void Function(double progress)? onProgress,
  }) async {
    final docId = 'doc_${DateTime.now().millisecondsSinceEpoch}';
    final ext = fileType.replaceAll('.', '');
    final storagePath = '$docId.$ext';

    var contentType = 'application/octet-stream';
    if (ext == 'pdf') {
      contentType = 'application/pdf';
    } else if (ext == 'pptx') {
      contentType =
          'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    } else if (ext == 'png') {
      contentType = 'image/png';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      contentType = 'image/jpeg';
    }

    // 1. Upload to Storage Bucket
    await _dio.uploadStorageFile(
      storagePath: storagePath,
      fileBytes: fileBytes,
      contentType: contentType,
      onProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    // 2. Register metadata row in documents table
    final res = await _client.createDocumentRecord(
      {
        'filename': filename,
        'file_type': fileType,
        'file_size_bytes': fileBytes.lengthInBytes,
        'storage_path': storagePath,
        'content_hash': contentHash,
        'processing_status': 'uploaded',
      },
    );

    final list = res.data is List ? (res.data as List) : <dynamic>[];
    if (list.isEmpty) {
      throw Exception('Failed to insert document record');
    }
    return DocumentUploadModel.fromJson(list.first as Map<String, dynamic>);
  }

  @override
  Future<List<OcrExtractionModel>> processStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  }) async {
    final res = await _client.triggerParseStemOcr(
      {
        'documentId': documentId,
        'storagePath': storagePath,
        'fileType': fileType,
      },
    );

    final result = res.data is Map<String, dynamic>
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final rawList = result['snippets'] as List<dynamic>? ?? [];
    if (rawList.isNotEmpty) {
      return rawList
          .map((e) => OcrExtractionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Fallback: fetch from DB directly
    return fetchExtractedSnippets(documentId);
  }

  @override
  Future<List<OcrExtractionModel>> fetchExtractedSnippets(
    String documentId,
  ) async {
    final res = await _client.fetchExtractedSnippets(
      {
        'select': '*',
        'document_id': 'eq.$documentId',
        'order': 'created_at.asc',
      },
    );
    final list = res.data is List ? (res.data as List) : <dynamic>[];
    return list
        .map((e) => OcrExtractionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DocumentUploadModel>> fetchUserDocuments() async {
    final res = await _client.fetchDocuments(
      {
        'select': '*',
        'order': 'created_at.desc',
      },
    );
    final list = res.data is List ? (res.data as List) : <dynamic>[];
    return list
        .map((e) => DocumentUploadModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
