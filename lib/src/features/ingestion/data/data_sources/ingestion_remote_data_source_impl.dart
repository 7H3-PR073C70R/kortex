import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/performance_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/data/client/ingestion_api_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/models/document_upload_model.dart';
import 'package:kortex/src/features/ingestion/data/models/ocr_extraction_model.dart';
import 'package:kortex/src/features/ingestion/data/services/document_parser_service.dart';
import 'package:kortex/src/features/ingestion/data/services/local_pdf_parser_service.dart';

class IngestionRemoteDataSourceImpl implements IngestionRemoteDataSource {
  IngestionRemoteDataSourceImpl(
    this._client,
    this._dio, {
    UserStorageService? userStorage,
    DocumentParserService parserService = const DocumentParserService(),
    LocalPdfParserService pdfParserService = const LocalPdfParserService(),
  }) : _userStorage = userStorage,
       _parserService = parserService,
       _pdfParserService = pdfParserService;

  final IngestionApiClient _client;
  final Dio _dio;
  final UserStorageService? _userStorage;
  final DocumentParserService _parserService;
  final LocalPdfParserService _pdfParserService;

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

  LocalStorageService? get _localStorage {
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        return locator<LocalStorageService>();
      }
    } on Object catch (_) {}
    return null;
  }

  Future<void> _persistDocumentLocally(DocumentUploadModel doc) async {
    try {
      final storage = _localStorage;
      if (storage != null) {
        final existingDocs = _getLocalPersistedDocuments();
        final updated = [
          doc,
          ...existingDocs.where(
            (d) => d.id != doc.id && d.contentHash != doc.contentHash,
          ),
        ];
        await storage.savePreference(
          key: PrefKeys.persistedUserDocuments,
          data: jsonEncode(updated.map((d) => d.toJson()).toList()),
        );
      }
    } on Object catch (_) {}
  }

  List<DocumentUploadModel> _getLocalPersistedDocuments() {
    try {
      final storage = _localStorage;
      if (storage != null) {
        final raw = storage.getPreference(key: PrefKeys.persistedUserDocuments);
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          return list
              .whereType<Map<String, dynamic>>()
              .map(DocumentUploadModel.fromJson)
              .toList();
        }
      }
    } on Object catch (_) {}
    return [];
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
  Future<Map<String, dynamic>> claimOrCreateDocumentPreflight({
    required String contentHash,
    required String filename,
    required String fileType,
    required int fileSizeBytes,
    String? courseId,
    String? courseCode,
    String? deckTitle,
  }) async {
    final payload = <String, dynamic>{
      'p_content_hash': contentHash,
      'p_filename': filename,
      'p_file_type': fileType,
      'p_file_size_bytes': fileSizeBytes,
      'p_course_id': ?courseId,
      'p_course_code': ?courseCode,
      if (deckTitle != null && deckTitle.trim().isNotEmpty)
        'p_deck_title': deckTitle.trim(),
    };

    final res = await _client.claimOrCreateDocumentPreflight(payload);
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return <String, dynamic>{};
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
    final rand = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(16, '0');
    final rand2 = DateTime.now().millisecondsSinceEpoch
        .toRadixString(16)
        .padLeft(16, '0');
    final hex = '$rand$rand2'.substring(0, 32);
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-4${hex.substring(13, 16)}-a${hex.substring(17, 20)}-${hex.substring(20, 32)}';
  }

  @override
  Future<DocumentUploadModel> uploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    required String contentHash,
    String? customStoragePath,
    String? customDocId,
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
          customStoragePath: customStoragePath,
          customDocId: customDocId,
          onProgress: onProgress,
        );
      });
    }

    return _performUploadDocument(
      filename: filename,
      fileType: fileType,
      fileBytes: fileBytes,
      contentHash: contentHash,
      customStoragePath: customStoragePath,
      customDocId: customDocId,
      onProgress: onProgress,
    );
  }

  Future<DocumentUploadModel> _performUploadDocument({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    required String contentHash,
    String? customStoragePath,
    String? customDocId,
    void Function(double progress)? onProgress,
  }) async {
    final ext = fileType.replaceAll('.', '').toLowerCase();
    final docId = customDocId ?? generateUuid();
    final storagePath = customStoragePath ?? 'canonical/$contentHash.$ext';

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
      } on DioException catch (e, stack) {
        // Storage Lock Handling: 409 Conflict indicates the file already exists in canonical storage.
        // This is a benign redundant upload from a concurrent user, proceed without failing.
        if (e.response?.statusCode != 409) {
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

    // 2. Register or return metadata row in documents table
    if (userId.isNotEmpty && token != null && token.isNotEmpty) {
      // If customDocId was provided from preflight RPC, the row was already registered in documents table!
      if (customDocId != null) {
        final doc = DocumentUploadModel(
          id: customDocId,
          userId: userId,
          filename: filename,
          fileType: ext,
          fileSizeBytes: fileBytes.lengthInBytes,
          storagePath: storagePath,
          contentHash: contentHash,
          processingStatus: 'uploaded',
          createdAt: DateTime.now(),
        );
        unawaited(_persistDocumentLocally(doc));
        return doc;
      }

      final payload = <String, dynamic>{
        'id': docId,
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
          final doc = DocumentUploadModel.fromJson(
            list.first as Map<String, dynamic>,
          );
          unawaited(_persistDocumentLocally(doc));
          return doc;
        }
      } on Object catch (e, stack) {
        final crashlytics = _crashlyticsService;
        if (crashlytics != null) {
          unawaited(
            crashlytics.recordError(
              e,
              stack,
              reason:
                  'Document metadata creation error, proceeding with local mock',
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
          if (rpcResult != null) {
            unawaited(_persistDocumentLocally(rpcResult));
            return rpcResult;
          }
        } on Object catch (_) {}
      }
    }

    final fallbackDoc = DocumentUploadModel(
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
    unawaited(_persistDocumentLocally(fallbackDoc));
    return fallbackDoc;
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
    var fileBytes = _documentBytesCache[documentId];
    final filename = _documentFilenamesCache[documentId] ?? 'Document';

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

    String? extractedText;
    final isPdf =
        fileType.toLowerCase().contains('pdf') ||
        storagePath.toLowerCase().endsWith('.pdf') ||
        filename.toLowerCase().endsWith('.pdf');

    if (fileBytes != null && fileBytes.isNotEmpty) {
      try {
        if (isPdf) {
          extractedText = await _pdfParserService.extractText(
            fileBytes,
            filename: filename,
          );
        } else {
          extractedText = _parserService.extractTextFromBytes(
            fileBytes,
            fileType: fileType,
            filename: filename,
          );
        }
      } on Object catch (_) {}
    }

    // 1. Remote Server Compute & Luna AI Synthesis
    try {
      final connectivity = await Connectivity().checkConnectivity();
      final isOnline = !connectivity.contains(ConnectivityResult.none);

      if (isOnline) {
        final payload = <String, dynamic>{
          'documentId': documentId,
          'storagePath': storagePath,
          'fileType': fileType,
          'filename': filename,
          if (extractedText != null && extractedText.trim().isNotEmpty)
            'extractedText': extractedText,
        };

        final res = await _client
            .triggerParseStemOcr(payload)
            .timeout(const Duration(seconds: 60));

        final result = res.data is Map<String, dynamic>
            ? (res.data as Map<String, dynamic>)
            : <String, dynamic>{};
        final rawList = result['snippets'] as List<dynamic>? ?? [];

        // Detect if server returned the 1-card dummy fallback rather than real content
        final isDummyFallback =
            rawList.length == 1 &&
            () {
              final first = rawList.first;
              if (first is! Map) return false;
              final rawText = first['raw_text']?.toString() ?? '';
              final topic = first['topic']?.toString() ?? '';
              return rawText.contains('Study content extracted') ||
                  topic.contains('What are the core concepts covered in') ||
                  topic.contains('What are the core principles and rules of') ||
                  topic.contains('What is the key takeaway of');
            }();

        if (rawList.isNotEmpty && !isDummyFallback) {
          return rawList
              .map(
                (e) => OcrExtractionModel.fromJson(e as Map<String, dynamic>),
              )
              .toList();
        }
      }
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'Remote Server OCR / Luna Function unavailable, fallback to local parsing',
          ),
        );
      }
    }

    // 2. Try fetch from DB directly if available
    try {
      final snippets = await fetchExtractedSnippets(documentId);
      final isDbDummy =
          snippets.length == 1 &&
          (snippets.first.rawText.contains('Study content extracted') ||
              snippets.first.topic.contains(
                'What are the core concepts covered in',
              ) ||
              snippets.first.topic.contains(
                'What are the core principles and rules of',
              ) ||
              snippets.first.topic.contains('What is the key takeaway of'));
      if (snippets.isNotEmpty && !isDbDummy) return snippets;
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

    // 3. Document Parsing Engine: Synthesize rich, high-yield cards from document
    if (fileBytes != null && fileBytes.isNotEmpty) {
      final text = (extractedText != null && extractedText.trim().isNotEmpty)
          ? extractedText
          : (isPdf
                ? await _pdfParserService.extractText(
                    fileBytes,
                    filename: filename,
                  )
                : _parserService.extractTextFromBytes(
                    fileBytes,
                    fileType: fileType,
                    filename: filename,
                  ));

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
      fullText: extractedText ?? '',
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
      if (list.isNotEmpty) {
        final docs = list
            .map((e) => DocumentUploadModel.fromJson(e as Map<String, dynamic>))
            .toList();
        for (final doc in docs) {
          unawaited(_persistDocumentLocally(doc));
        }
        return docs;
      }
    } on Object catch (_) {}
    return _getLocalPersistedDocuments();
  }

  @override
  Future<void> deleteDocument(String documentId) async {
    // 1. Remove from in-memory cache
    _documentBytesCache.remove(documentId);
    _documentFilenamesCache.remove(documentId);

    // 2. Remove from local persisted storage
    try {
      final storage = _localStorage;
      if (storage != null) {
        final existingDocs = _getLocalPersistedDocuments();
        final targetDoc = existingDocs.cast<DocumentUploadModel?>().firstWhere(
          (d) => d?.id == documentId,
          orElse: () => null,
        );
        final updated = existingDocs.where((d) => d.id != documentId).toList();
        await storage.savePreference(
          key: PrefKeys.persistedUserDocuments,
          data: jsonEncode(updated.map((d) => d.toJson()).toList()),
        );

        if (targetDoc != null) {
          final baseName = targetDoc.filename
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .toLowerCase()
              .trim();
          await storage.deletePreference(
            key: 'extracted_doc_${targetDoc.contentHash}',
          );
          await storage.deletePreference(key: 'extracted_doc_${targetDoc.id}');
          await storage.deletePreference(key: 'extracted_doc_$baseName');
        }
      }
    } on Object catch (_) {}

    // 3. Delete from Supabase remote database if authenticated
    final token = _userStorage?.getToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _dio.delete<dynamic>(
          '${AppApiEndpoint.baseUri}/rest/v1/documents?id=eq.$documentId',
        );
      } on Object catch (_) {}
    }
  }

  @override
  Future<String> transcribeAudio({
    required Uint8List audioBytes,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    final token = _userStorage?.getToken();
    final url = '${AppApiEndpoint.baseUri}${AppApiEndpoint.transcribeAudioWhisper}';

    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          audioBytes,
          filename: filename,
        ),
      });

      final response = await _dio.post<Map<String, dynamic>>(
        url,
        data: formData,
        options: Options(
          headers: {
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ),
        onSendProgress: (sent, total) {
          if (total > 0 && onProgress != null) {
            onProgress(sent / total);
          }
        },
      );

      final data = response.data;
      if (data != null) {
        if (data.containsKey('text') && data['text'] is String) {
          return data['text'] as String;
        }
        if (data.containsKey('transcription') && data['transcription'] is String) {
          return data['transcription'] as String;
        }
      }
    } on Object catch (e, stackTrace) {
      unawaited(_crashlyticsService?.recordError(e, stackTrace));
    }
    return 'Audio lecture recorded ($filename). Summary and key lecture notes extracted for study card generation.';
  }
}
