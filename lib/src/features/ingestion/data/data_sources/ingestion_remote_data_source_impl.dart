import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/performance_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/data/client/ingestion_api_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/models/document_upload_model.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';

class IngestionRemoteDataSourceImpl implements IngestionRemoteDataSource {
  IngestionRemoteDataSourceImpl(
    this._client,
    this._dio, {
    UserStorageService? userStorage,
    DocumentParserService parserService = const DocumentParserService(),
  }) : _userStorage = userStorage,
       _parserService = parserService;

  final IngestionApiClient _client;
  final Dio _dio;
  final UserStorageService? _userStorage;
  final DocumentParserService _parserService;

  PerformanceService? get _performanceService {
    try {
      return locator<PerformanceService>();
    } on Object catch (_) {
      return null;
    }
  }

  CrashlyticsService? get _crashlyticsService {
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

  final Map<String, Uint8List> _documentBytesCache = {};
  final Map<String, String> _documentFilenamesCache = {};

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

  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String str) {
    return _uuidRegex.hasMatch(str);
  }

  static String generateUuid() {
    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0');
    final rand2 = DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(16, '0');
    final hex = '$rand$rand2'.substring(0, 32);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
  }

  @override
  Future<DocumentUploadModel> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    required String contentHash,
    void Function(double progress)? onProgress,
  }) async {
    final performance = _performanceService;
    if (performance != null) {
      return performance.traceAction('document_upload', (trace) async {
        trace
          ..putAttribute('filename', filename)
          ..putAttribute('file_type', fileType)
          ..setMetric('file_size_bytes', fileBytes.lengthInBytes);
        return _performUploadDocument(
          filename: filename,
          fileType: fileType,
          fileBytes: fileBytes,
          contentHash: contentHash,
          onProgress: onProgress,
        );
      });
    }

    return _performUploadDocument(
      filename: filename,
      fileType: fileType,
      fileBytes: fileBytes,
      contentHash: contentHash,
      onProgress: onProgress,
    );
  }

  Future<DocumentUploadModel> _performUploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    required String contentHash,
    void Function(double progress)? onProgress,
  }) async {
    final docId = generateUuid();
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

    _documentBytesCache[docId] = fileBytes;
    _documentFilenamesCache[docId] = filename;

    final token = _userStorage?.getToken();
    final userId = _userStorage?.getUserId() ?? '';

    // 1. Upload to Storage Bucket (when active authenticated session exists)
    if (token != null && token.isNotEmpty) {
      try {
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
      } on Object catch (e, stack) {
        final crashlytics = _crashlyticsService;
        if (crashlytics != null) {
          unawaited(
            crashlytics.recordError(
              e,
              stack,
              reason:
                  'Document storage upload error, proceeding with local cache',
            ),
          );
        }
      }
    }

    // 2. Register metadata row in documents table with authenticated user_id
    if (userId.isNotEmpty && token != null && token.isNotEmpty) {
      final payload = <String, dynamic>{
        'filename': filename,
        'file_type': fileType,
        'file_size_bytes': fileBytes.lengthInBytes,
        'storage_path': storagePath,
        'content_hash': contentHash,
        'processing_status': 'uploaded',
        'user_id': userId,
      };

      try {
        final res = await _client.createDocumentRecord(payload);
        final list = res.data is List ? (res.data as List) : <dynamic>[];
        if (list.isNotEmpty) {
          return DocumentUploadModel.fromJson(
            list.first as Map<String, dynamic>,
          );
        }
      } on Object catch (e, stack) {
        final crashlytics = _crashlyticsService;
        if (crashlytics != null) {
          unawaited(
            crashlytics.recordError(
              e,
              stack,
              reason: 'Document record insert error, attempting RPC reference',
            ),
          );
        }
        // If RLS or DB rejects direct insert, attempt RPC or fallback
        try {
          final rpcResult = await findOrCreateDocumentReference(
            contentHash: contentHash,
            filename: filename,
            fileType: fileType,
            fileSizeBytes: fileBytes.lengthInBytes,
          );
          if (rpcResult != null) return rpcResult;
        } on Object catch (_) {}
      }
    }

    return DocumentUploadModel(
      id: docId,
      userId: userId,
      filename: filename,
      fileType: fileType,
      fileSizeBytes: fileBytes.lengthInBytes,
      storagePath: storagePath,
      contentHash: contentHash,
      processingStatus: 'uploaded',
      createdAt: DateTime.now(),
    );
  }

  @override
  void cacheDocumentBytes(
    String documentId,
    Uint8List fileBytes, {
    String? filename,
  }) {
    _documentBytesCache[documentId] = fileBytes;
    if (filename != null && filename.isNotEmpty) {
      _documentFilenamesCache[documentId] = filename;
    }
  }

  @override
  Future<List<OcrExtractionModel>> processStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  }) async {
    final performance = _performanceService;
    if (performance != null) {
      return performance.traceAction('document_ingestion_ocr', (trace) async {
        trace
          ..putAttribute('document_id', documentId)
          ..putAttribute('file_type', fileType);
        return _performProcessStemOcr(
          documentId: documentId,
          storagePath: storagePath,
          fileType: fileType,
        );
      });
    }

    return _performProcessStemOcr(
      documentId: documentId,
      storagePath: storagePath,
      fileType: fileType,
    );
  }

  Future<List<OcrExtractionModel>> _performProcessStemOcr({
    required String documentId,
    required String storagePath,
    required String fileType,
  }) async {
    // Pre-extract text from cache if available so Edge function gets it immediately
    var fileBytes = _documentBytesCache[documentId];
    final filename = _documentFilenamesCache[documentId] ?? 'Document';
    var initialText = '';
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final isPdf = fileType.toLowerCase().contains('pdf') ||
          storagePath.toLowerCase().endsWith('.pdf') ||
          filename.toLowerCase().endsWith('.pdf');
      initialText = _parserService.extractTextFromBytes(
        fileBytes,
        fileType: isPdf ? 'pdf' : fileType,
        filename: filename,
      );
    }

    // 1. Try remote Edge Function (AI Smart Synthesis)
    try {
      final payload = <String, dynamic>{
        'documentId': documentId,
        'storagePath': storagePath,
        'fileType': fileType,
      };
      if (initialText.isNotEmpty) {
        payload['extractedText'] = initialText;
      }

      final res = await _client.triggerParseStemOcr(payload);

      final result = res.data is Map<String, dynamic>
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final rawList = result['snippets'] as List<dynamic>? ?? [];
      if (rawList.isNotEmpty) {
        return rawList
            .map((e) => OcrExtractionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'Remote OCR Edge Function unavailable, fallback to local parsing',
          ),
        );
      }
    }

    // 2. Try fetch from DB directly if available
    try {
      final snippets = await fetchExtractedSnippets(documentId);
      if (snippets.isNotEmpty) return snippets;
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'Fetching extracted snippets from DB failed, fallback to local parsing',
          ),
        );
      }
    }

    // 3. Document Parsing Engine: Extract text & images from uploaded document

    // If bytes not in memory cache, attempt download from storage bucket
    if ((fileBytes == null || fileBytes.isEmpty) && storagePath.isNotEmpty) {
      try {
        final res = await _dio.get<List<int>>(
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.storageBucket}/$storagePath',
          options: Options(responseType: ResponseType.bytes),
        );
        if (res.data != null && res.data!.isNotEmpty) {
          fileBytes = Uint8List.fromList(res.data!);
          _documentBytesCache[documentId] = fileBytes;
        }
      } on Object catch (_) {}
    }

    if (fileBytes != null && fileBytes.isNotEmpty) {
      String text;
      final isPdf = fileType.toLowerCase().contains('pdf') ||
          storagePath.toLowerCase().endsWith('.pdf') ||
          filename.toLowerCase().endsWith('.pdf');
      if (isPdf) {
        text = _parserService.extractTextFromBytes(
          fileBytes,
          fileType: 'pdf',
          filename: filename,
        );
      } else {
        text = _parserService.extractTextFromBytes(
          fileBytes,
          fileType: fileType,
          filename: filename,
        );
      }

      final token = _userStorage?.getToken();
      final extractedImages = _parserService.extractImagesFromPdfBytes(
        fileBytes,
      );
      final uploadedImageUrls = <String>[];

      // Upload extracted diagrams to Supabase Storage `card-assets` bucket
      for (var i = 0; i < extractedImages.length; i++) {
        final img = extractedImages[i];
        final assetPath = '${documentId}_img_${i + 1}.${img.extension}';
        final contentType = img.extension == 'png' ? 'image/png' : 'image/jpeg';

        if (token != null && token.isNotEmpty) {
          try {
            await _dio.uploadStorageFile(
              storagePath: assetPath,
              fileBytes: img.bytes,
              contentType: contentType,
              bucket: AppApiEndpoint.cardAssetsBucket,
            );
          } on Object catch (_) {}
        }

        final publicUrl = AppApiEndpoint.getCardAssetPublicUrl(assetPath);
        uploadedImageUrls.add(publicUrl);
      }

      final snippets = _parserService.synthesizeSnippetsFromDocument(
        documentId: documentId,
        fullText: text,
        filename: filename,
        imageUrls: uploadedImageUrls,
      );
      return snippets;
    }

    return _parserService.synthesizeSnippetsFromDocument(
      documentId: documentId,
      fullText: '',
      filename: filename,
    );
  }

  @override
  Future<List<OcrExtractionModel>> fetchExtractedSnippets(
    String documentId,
  ) async {
    if (!isValidUuid(documentId)) {
      return [];
    }

    try {
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
    } on Object catch (_) {
      return [];
    }
  }

  @override
  Future<List<DocumentUploadModel>> fetchUserDocuments() async {
    try {
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
    } on Object catch (_) {
      return [];
    }
  }
}
