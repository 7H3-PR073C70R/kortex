import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/ingestion/domain/entities/document_upload_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';

class FetchUserDocumentsUseCase {
  const FetchUserDocumentsUseCase(this._repository);

  final IngestionRepository _repository;

  Future<Either<Failure, List<DocumentUploadEntity>>> call() {
    return _repository.fetchUserDocuments();
  }
}
