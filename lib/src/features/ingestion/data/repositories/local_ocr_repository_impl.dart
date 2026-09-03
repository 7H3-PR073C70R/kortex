import 'dart:typed_data';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ocr_local_data_source.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/local_ocr_repository.dart';

class LocalOcrRepositoryImpl implements LocalOcrRepository {
  LocalOcrRepositoryImpl({
    required OcrLocalDataSource localDataSource,
    required IngestionRemoteDataSource remoteDataSource,
  }) : _local = localDataSource,
       _remote = remoteDataSource;

  final OcrLocalDataSource _local;
  final IngestionRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<RecognizedTextBlock>>> processLiveCameraFrame({
    required Uint8List frameBytes,
    String? imagePath,
  }) {
    return _local
        .processFrame(
          frameBytes,
          imagePath: imagePath,
        )
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<OcrExtractionEntity>>> processCapturedImage({
    required Uint8List imageBytes,
    required String documentId,
    String? imagePath,
    bool isOnline = true,
  }) {
    return Future<List<OcrExtractionEntity>>.sync(() async {
      // 1. Instant on-device ML Kit OCR extraction
      final localEntities = await _local.extractFromImage(
        imageBytes,
        documentId: documentId,
        imagePath: imagePath,
      );

      final combinedRawText = localEntities.map((e) => e.rawText).join('\n');

      // 2. Queue for offline sync
      await _local.queueForSync(
        documentId: documentId,
        rawText: combinedRawText,
        localPath: imagePath ?? '',
      );

      // 3. Attempt cloud LaTeX enhancement handshake if online
      if (isOnline) {
        try {
          final cloudModels = await _remote.processStemOcr(
            documentId: documentId,
            storagePath: imagePath ?? 'camera/$documentId.jpg',
            fileType: 'image/jpeg',
          );
          await _local.markSyncComplete(documentId);
          if (cloudModels.isNotEmpty) {
            return cloudModels.map((m) => m.toEntity()).toList();
          }
        } on Object catch (_) {
          // If remote fails, seamlessly return local extraction
        }
      }

      return localEntities;
    }).makeRequest();
  }

  @override
  Future<Either<Failure, int>> getPendingSyncCount() {
    return _local
        .getPendingSyncItems()
        .then((items) => items.length)
        .makeRequest();
  }

  @override
  Future<Either<Failure, int>> synchronizePendingQueue() {
    return Future<int>.sync(() async {
      final items = await _local.getPendingSyncItems();
      var syncedCount = 0;

      for (final item in items) {
        final docId = item['document_id'] as String? ?? '';
        final localPath = item['local_path'] as String? ?? '';
        if (docId.isEmpty) continue;

        try {
          await _remote.processStemOcr(
            documentId: docId,
            storagePath: localPath.isNotEmpty ? localPath : 'camera/$docId.jpg',
            fileType: 'image/jpeg',
          );
          await _local.markSyncComplete(docId);
          syncedCount++;
        } on Object catch (_) {
          // Keep item in queue for next sync cycle
        }
      }

      return syncedCount;
    }).makeRequest();
  }
}
