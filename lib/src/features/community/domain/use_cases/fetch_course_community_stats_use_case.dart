import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

/// Use case that fetches active study room count, peer count,
/// and forum activity for a course community.
class FetchCourseCommunityStatsUseCase {
  const FetchCourseCommunityStatsUseCase(this._repository);

  final CommunityRepository _repository;

  Future<Either<Failure, StudyCommunityEntity>> call(String courseCode) {
    return _repository.fetchCourseCommunityStats(courseCode);
  }
}
