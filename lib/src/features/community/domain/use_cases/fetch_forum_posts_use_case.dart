import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

class FetchForumPostsUseCase {
  const FetchForumPostsUseCase(this._repository);

  final CommunityRepository _repository;

  Future<Either<Failure, List<ForumPostEntity>>> call({String? track}) {
    return _repository.fetchForumPosts(track: track);
  }
}
