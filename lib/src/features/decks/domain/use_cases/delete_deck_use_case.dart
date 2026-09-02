import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class DeleteDeckUseCase implements UseCase<void, String> {
  const DeleteDeckUseCase(this._repository);

  final DecksRepository _repository;

  @override
  Future<Either<Failure, void>> call(String deckId) {
    return _repository.deleteDeck(deckId);
  }
}
