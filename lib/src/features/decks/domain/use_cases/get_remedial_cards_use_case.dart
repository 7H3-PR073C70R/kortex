import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class GetRemedialCardsUseCase
    implements UseCase<List<FlashcardEntity>, String> {
  const GetRemedialCardsUseCase(this._repository);

  final DecksRepository _repository;

  @override
  Future<Either<Failure, List<FlashcardEntity>>> call(String deckId) async {
    final result = await _repository.getDeckCards(deckId);
    return result.fold(
      Left.new,
      (cards) {
        final filtered = cards.where((card) {
          final isLowEase = card.easeFactor < 2.1;
          final isDueOrLapsed =
              card.isDueToday || (card.repetitions == 0 && card.lastReviewed != null);
          return isLowEase || isDueOrLapsed;
        }).toList();
        return Right(filtered);
      },
    );
  }
}
