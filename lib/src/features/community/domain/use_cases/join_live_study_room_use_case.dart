import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

class JoinLiveStudyRoomUseCase {
  const JoinLiveStudyRoomUseCase(this._repository);

  final CommunityRepository _repository;

  Stream<StudyRoomEntity> call(String roomId) {
    return _repository.watchStudyRoom(roomId);
  }
}
