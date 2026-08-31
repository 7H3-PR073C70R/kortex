import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/ingestion/domain/entities/ocr_extraction_entity.dart';
import 'package:kortex/src/features/ingestion/domain/repositories/ingestion_repository.dart';

class GenerateFlashcardsFromDocUseCase {
  const GenerateFlashcardsFromDocUseCase(this._repository);

  final IngestionRepository _repository;

  Future<Either<Failure, DeckEntity>> call({
    required String documentId,
    required String deckTitle,
    required String subject,
    required List<OcrExtractionEntity> snippets,
  }) {
    return _repository.generateFlashcardsFromDoc(
      documentId: documentId,
      deckTitle: deckTitle,
      subject: subject,
      snippets: snippets,
    );
  }
}
