import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

class RateSharedDeckUseCase {
  const RateSharedDeckUseCase(this._repository);

  final CommunityRepository _repository;

  Future<Either<Failure, bool>> call({
    required String sharedDeckId,
    required double rating,
  }) {
    return _repository.rateSharedDeck(
      sharedDeckId: sharedDeckId,
      rating: rating,
    );
  }
}
