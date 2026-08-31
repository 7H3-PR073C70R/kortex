import 'dart:typed_data';
import 'package:kortex/src/features/ingestion/data/client/supabase_ingestion_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/models/document_upload_model.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/services/user_storage_service.dart';

class IngestionRemoteDataSourceImpl implements IngestionRemoteDataSource {
  IngestionRemoteDataSourceImpl(this._client, this._userStorage);

  final SupabaseIngestionClient _client;
  final UserStorageService _userStorage;

  @override
  Future<DocumentUploadModel?> findOrCreateDocumentReference({
    required String contentHash,
    required String filename,
    required String fileType,
    required int fileSizeBytes,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final data = await _client.findOrCreateDocumentReference(
      contentHash: contentHash,
      filename: filename,
      fileType: fileType,
      fileSizeBytes: fileSizeBytes,
      authToken: token,
    );
    if (data != null && data['document'] != null) {
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
    final token = _userStorage.getToken() ?? '';
    final data = await _client.findDocumentByHash(
      contentHash: contentHash,
      authToken: token,
    );
    if (data != null) {
      return DocumentUploadModel.fromJson(data, isDeduplicated: true);
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
    final token = _userStorage.getToken() ?? '';
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

    // 1. Upload to Supabase Storage Bucket
    await _client.uploadStorageFile(
      storagePath: storagePath,
      fileBytes: fileBytes,
      contentType: contentType,
      authToken: token,
      onProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    // 2. Register metadata row in documents table
    final data = await _client.createDocumentRecord(
      filename: filename,
      fileType: fileType,
      fileSizeBytes: fileBytes.lengthInBytes,
      storagePath: storagePath,
      contentHash: contentHash,
      authToken: token,
    );

    return DocumentUploadModel.fromJson(data);
  }

  @override
  Future<List<OcrExtractionModel>> processStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  }) async {
    final token = _userStorage.getToken() ?? '';
    final result = await _client.triggerParseStemOcr(
      documentId: documentId,
      storagePath: storagePath,
      fileType: fileType,
      authToken: token,
    );

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
    final token = _userStorage.getToken() ?? '';
    final data = await _client.fetchExtractedSnippets(
      documentId: documentId,
      authToken: token,
    );
    return data.map(OcrExtractionModel.fromJson).toList();
  }

  @override
  Future<List<DocumentUploadModel>> fetchUserDocuments() async {
    final token = _userStorage.getToken() ?? '';
    final data = await _client.fetchUserDocuments(token);
    return data.map(DocumentUploadModel.fromJson).toList();
  }
}
