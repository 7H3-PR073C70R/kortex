import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';

class StreamLeaderboardRankingsUseCase {
  const StreamLeaderboardRankingsUseCase(this._repository);

  final CommunityRepository _repository;

  Stream<List<LeaderboardEntryEntity>> call({String? track}) {
    return _repository.streamLeaderboards(track: track);
  }
}
