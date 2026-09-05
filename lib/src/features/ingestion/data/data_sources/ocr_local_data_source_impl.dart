import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/performance_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ocr_local_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

class OcrLocalDataSourceImpl implements OcrLocalDataSource {
  OcrLocalDataSourceImpl({
    required LocalMlkitOcrClient client,
    required LocalStorageService storageService,
  }) : _client = client,
       _storage = storageService;

  final LocalMlkitOcrClient _client;
  final LocalStorageService _storage;

  static const _syncQueueKey = 'kortex_ocr_sync_queue';

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

  @override
  Future<List<RecognizedTextBlock>> processFrame(
    Uint8List frameBytes, {
    String? imagePath,
  }) async {
    final performance = _performanceService;
    if (performance != null) {
      return performance.traceAction('ocr_process_frame', (trace) async {
        try {
          return await _client.processImageBytes(frameBytes, imagePath: imagePath);
        } catch (e, stack) {
          final crashlytics = _crashlyticsService;
          if (crashlytics != null) {
            unawaited(
              crashlytics.recordError(
                e,
                stack,
                reason: 'OcrLocalDataSource.processFrame failed',
              ),
            );
          }
          rethrow;
        }
      });
    }

    try {
      return await _client.processImageBytes(frameBytes, imagePath: imagePath);
    } catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason: 'OcrLocalDataSource.processFrame failed',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<List<OcrExtractionEntity>> extractFromImage(
    Uint8List imageBytes, {
    required String documentId,
    String? imagePath,
  }) async {
    final performance = _performanceService;
    if (performance != null) {
      return performance.traceAction('ocr_extract_from_image', (trace) async {
        trace.putAttribute('document_id', documentId);
        return _performExtractFromImage(
          imageBytes,
          documentId: documentId,
          imagePath: imagePath,
        );
      });
    }
    return _performExtractFromImage(
      imageBytes,
      documentId: documentId,
      imagePath: imagePath,
    );
  }

  Future<List<OcrExtractionEntity>> _performExtractFromImage(
    Uint8List imageBytes, {
    required String documentId,
    String? imagePath,
  }) async {
    try {
      final blocks = await _client.processImageBytes(
        imageBytes,
        imagePath: imagePath,
      );

      final results = <OcrExtractionEntity>[];
      for (var i = 0; i < blocks.length; i++) {
        final block = blocks[i];
        results.add(
          OcrExtractionEntity(
            id: 'ocr_local_${documentId}_$i',
            documentId: documentId,
            rawText: block.text,
            latexContent: block.text.contains(r'\') ? block.text : null,
            topic: 'Extracted STEM Content',
            confidenceScore: block.confidence,
          ),
        );
      }
      return results;
    } catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason: 'OcrLocalDataSource.extractFromImage failed',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> queueForSync({
    required String documentId,
    required String rawText,
    required String localPath,
  }) async {
    final list = await getPendingSyncItems()
      ..removeWhere((item) => item['document_id'] == documentId)
      ..add({
        'document_id': documentId,
        'raw_text': rawText,
        'local_path': localPath,
        'timestamp': DateTime.now().toIso8601String(),
      });

    await _storage.savePreference(
      key: _syncQueueKey,
      data: jsonEncode(list),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final raw = _storage.getPreference(key: _syncQueueKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List<dynamic>) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } on Object catch (_) {
      return [];
    }
  }

  @override
  Future<void> markSyncComplete(String documentId) async {
    final list = await getPendingSyncItems();
    list.removeWhere((item) => item['document_id'] == documentId);
    await _storage.savePreference(
      key: _syncQueueKey,
      data: jsonEncode(list),
    );
  }
}
