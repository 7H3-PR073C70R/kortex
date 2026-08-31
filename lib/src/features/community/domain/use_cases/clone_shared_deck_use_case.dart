import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class CloneSharedDeckUseCase {
  const CloneSharedDeckUseCase(this._repository);

  final CommunityRepository _repository;

  Future<Either<Failure, DeckEntity>> call(String sharedDeckId) {
    return _repository.cloneSharedDeck(sharedDeckId);
  }
}
