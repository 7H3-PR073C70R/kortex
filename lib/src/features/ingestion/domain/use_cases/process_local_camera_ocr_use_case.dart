import 'dart:typed_data';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/local_ocr_repository.dart';

/// Instantly parses captured textbook or lecture note camera images
/// using on-device ML Kit.
class ProcessLocalCameraOcrUseCase {
  const ProcessLocalCameraOcrUseCase(this._repository);

  final LocalOcrRepository _repository;

  Future<Either<Failure, List<OcrExtractionEntity>>> call({
    required Uint8List imageBytes,
    required String documentId,
    String? imagePath,
    bool isOnline = true,
  }) {
    return _repository.processCapturedImage(
      imageBytes: imageBytes,
      documentId: documentId,
      imagePath: imagePath,
      isOnline: isOnline,
    );
  }
}
