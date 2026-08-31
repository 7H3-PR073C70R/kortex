import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';

class GetUserDecksUseCase implements UseCase<List<DeckEntity>, NoParams> {
  const GetUserDecksUseCase(this._repository);

  final DecksRepository _repository;

  @override
  Future<Either<Failure, List<DeckEntity>>> call([NoParams? params]) {
    return _repository.getUserDecks();
  }
}
