import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/synthesis_mode.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';

class ProcessStemOcrUseCase {
  const ProcessStemOcrUseCase(this._repository);

  final IngestionRepository _repository;

  Future<Either<Failure, List<OcrExtractionEntity>>> call({
    required String documentId,
    required String storagePath,
    required String fileType,
    SynthesisMode synthesisMode = SynthesisMode.aiSmart,
  }) {
    return _repository.processStemOcr(
      documentId: documentId,
      storagePath: storagePath,
      fileType: fileType,
      synthesisMode: synthesisMode,
    );
  }
}
