import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class SaveSessionResultsParams {
  const SaveSessionResultsParams({
    required this.deckId,
    required this.cardsReviewed,
    required this.durationSeconds,
    required this.retentionScore,
  });

  final String deckId;
  final int cardsReviewed;
  final int durationSeconds;
  final double retentionScore;
}

class SaveSessionResultsUseCase
    implements UseCase<void, SaveSessionResultsParams> {
  const SaveSessionResultsUseCase(this._repository);

  final DecksRepository _repository;

  @override
  Future<Either<Failure, void>> call(SaveSessionResultsParams params) {
    return _repository.saveSessionResults(
      deckId: params.deckId,
      cardsReviewed: params.cardsReviewed,
      durationSeconds: params.durationSeconds,
      retentionScore: params.retentionScore,
    );
  }
}
