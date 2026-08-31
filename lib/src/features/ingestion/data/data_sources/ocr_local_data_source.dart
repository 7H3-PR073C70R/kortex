import 'dart:typed_data';
import 'package:kortex/src/features/ingestion/data/client/local_mlkit_ocr_client.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';

abstract class OcrLocalDataSource {
  Future<List<RecognizedTextBlock>> processFrame(
    Uint8List frameBytes, {
    String? imagePath,
  });

  Future<List<OcrExtractionEntity>> extractFromImage(
    Uint8List imageBytes, {
    required String documentId,
    String? imagePath,
  });

  Future<void> queueForSync({
    required String documentId,
    required String rawText,
    required String localPath,
  });

  Future<List<Map<String, dynamic>>> getPendingSyncItems();

  Future<void> markSyncComplete(String documentId);
}
