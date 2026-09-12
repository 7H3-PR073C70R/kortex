import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';

class EphemeralRoomRepositoryImpl implements EphemeralRoomRepository {
  EphemeralRoomRepositoryImpl({
    EphemeralPresenceClient? presenceClient,
    CommunityApiClient? communityClient,
  })  : _presenceClient = presenceClient ?? EphemeralPresenceClientImpl(),
        _communityClient = communityClient;

  final EphemeralPresenceClient _presenceClient;
  final CommunityApiClient? _communityClient;

  @override
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
    String? activeGoal,
  }) async {
    await _presenceClient.joinRoomPresence(
      roomId: roomId,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      activeGoal: activeGoal,
    );
  }

  @override
  Future<void> leaveRoomPresence(String roomId) async {
    await _presenceClient.leaveRoomPresence(roomId);
  }

  @override
  Future<void> broadcastPomodoroTick({
    required String roomId,
    required int remainingSeconds,
    required String pomodoroState,
    required String senderId,
  }) async {
    await _presenceClient.broadcastPomodoroTick(
      roomId: roomId,
      remainingSeconds: remainingSeconds,
      pomodoroState: pomodoroState,
      senderId: senderId,
    );
  }

  @override
  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  }) async {
    await _presenceClient.broadcastHandRaise(
      roomId: roomId,
      userId: userId,
      isHandRaised: isHandRaised,
    );
  }

  @override
  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  }) async {
    await _presenceClient.broadcastMuteState(
      roomId: roomId,
      userId: userId,
      isMuted: isMuted,
    );
  }

  @override
  Future<void> broadcastAwayState({
    required String roomId,
    required String userId,
    required bool isAway,
  }) async {
    await _presenceClient.broadcastAwayState(
      roomId: roomId,
      userId: userId,
      isAway: isAway,
    );
  }

  @override
  Future<void> broadcastGoal({
    required String roomId,
    required String userId,
    required String? goal,
  }) async {
    await _presenceClient.broadcastGoal(
      roomId: roomId,
      userId: userId,
      goal: goal,
    );
  }

  @override
  Future<void> broadcastWhiteboardStroke({
    required String roomId,
    required WhiteboardStroke stroke,
  }) async {
    await _presenceClient.broadcastWhiteboardStroke(
      roomId: roomId,
      stroke: stroke,
    );
  }

  @override
  Future<void> broadcastWhiteboardClear({required String roomId}) async {
    await _presenceClient.broadcastWhiteboardClear(roomId: roomId);
  }

  @override
  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  }) async {
    await _presenceClient.broadcastChatMessage(
      roomId: roomId,
      message: message,
    );
  }

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) {
    return _presenceClient.watchParticipants(roomId);
  }

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) {
    return _presenceClient.watchPomodoroSync(roomId);
  }

  @override
  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId) {
    return _presenceClient.watchWhiteboardStrokes(roomId);
  }

  @override
  Stream<void> watchWhiteboardClear(String roomId) {
    return _presenceClient.watchWhiteboardClear(roomId);
  }

  @override
  Stream<RoomChatMessage> watchChatMessages(String roomId) {
    return _presenceClient.watchChatMessages(roomId);
  }

  @override
  Future<Either<Failure, void>> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) {
    return Future<void>.sync(() async {
      if (_communityClient != null) {
        await _communityClient.recordStudySession(
          {
            'room_id': roomId,
            'duration_minutes': durationMinutes,
            'subject': subject,
            'completed_at': DateTime.now().toIso8601String(),
          },
        );
      }
    }).makeRequest();
  }
}
