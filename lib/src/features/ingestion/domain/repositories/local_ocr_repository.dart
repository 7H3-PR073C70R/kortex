import 'dart:typed_data';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

abstract class LocalOcrRepository {
  /// Processes live camera frame and returns detected text bounding blocks.
  Future<Either<Failure, List<RecognizedTextBlock>>> processLiveCameraFrame({
    required Uint8List frameBytes,
    String? imagePath,
  });

  /// Extracts text from captured image locally, queues for sync, and syncs
  /// to Supabase when online.
  Future<Either<Failure, List<OcrExtractionEntity>>> processCapturedImage({
    required Uint8List imageBytes,
    required String documentId,
    String? imagePath,
    bool isOnline = true,
  });

  /// Fetches pending offline OCR synchronization items count.
  Future<Either<Failure, int>> getPendingSyncCount();

  /// Synchronizes all queued local OCR items with Supabase Edge Functions.
  Future<Either<Failure, int>> synchronizePendingQueue();
}
