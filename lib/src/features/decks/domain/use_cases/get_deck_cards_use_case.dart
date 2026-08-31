import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class GetDeckCardsUseCase implements UseCase<List<FlashcardEntity>, String> {
  const GetDeckCardsUseCase(this._repository);

  final DecksRepository _repository;

  @override
  Future<Either<Failure, List<FlashcardEntity>>> call(String deckId) {
    return _repository.getDeckCards(deckId);
  }
}
