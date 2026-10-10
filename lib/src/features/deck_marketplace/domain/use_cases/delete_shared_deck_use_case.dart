import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

class DeleteSharedDeckUseCase {
  const DeleteSharedDeckUseCase(this._repository);

  final CommunityRepository _repository;

  Future<Either<Failure, bool>> call(String sharedDeckId) {
    return _repository.deleteSharedDeck(sharedDeckId);
  }
}
