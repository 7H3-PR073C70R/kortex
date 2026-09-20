import 'dart:typed_data';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';

class UploadStudyDocumentUseCase {
  const UploadStudyDocumentUseCase(this._repository);

  final IngestionRepository _repository;

  Future<Either<Failure, DocumentUploadEntity>> call({
    required String filename,
    required String fileType,
    required Uint8List fileBytes,
    String? courseId,
    String? courseCode,
    String? deckTitle,
    void Function(double progress)? onProgress,
  }) {
    return _repository.uploadDocument(
      filename: filename,
      fileType: fileType,
      fileBytes: fileBytes,
      courseId: courseId,
      courseCode: courseCode,
      deckTitle: deckTitle,
      onProgress: onProgress,
    );
  }
}
