import 'dart:typed_data';
import 'package:kortex/src/features/ingestion/data/models/document_upload_model.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';

abstract class IngestionRemoteDataSource {
  Future<DocumentUploadModel?> findOrCreateDocumentReference({
    required String contentHash,
    required String filename,
    required String fileType,
    required int fileSizeBytes,
  });

  Future<DocumentUploadModel?> findDocumentByHash(String contentHash);

  Future<DocumentUploadModel> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    required String contentHash,
    void Function(double progress)? onProgress,
  });

  Future<List<OcrExtractionModel>> processStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  });

  Future<List<OcrExtractionModel>> fetchExtractedSnippets(String documentId);

  Future<List<DocumentUploadModel>> fetchUserDocuments();
  void cacheDocumentBytes(String documentId, Uint8List fileBytes, {String? filename});
}
