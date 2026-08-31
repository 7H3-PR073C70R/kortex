import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

/// Use case that checks if a course community hub exists and auto-provisions
/// or enrolls the student into the community.
class AutoProvisionCommunityUseCase {
  const AutoProvisionCommunityUseCase(this._repository);

  final CommunityRepository _repository;

  Future<Either<Failure, StudyCommunityEntity>> call({
    required String courseCode,
    required String title,
    String? department,
  }) {
    return _repository.autoProvisionCommunity(
      courseCode: courseCode,
      title: title,
      department: department,
    );
  }
}
