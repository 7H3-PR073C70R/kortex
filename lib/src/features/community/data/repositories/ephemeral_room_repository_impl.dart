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
  }) async {
    final participant = EphemeralParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      joinedAt: DateTime.now(),
    );
    await _presenceClient.joinRoomChannel(
      roomId: roomId,
      participant: participant,
    );
  }

  @override
  Future<void> leaveRoomPresence(String roomId) async {
    await _presenceClient.leaveRoomChannel(roomId);
  }

  @override
  Future<void> broadcastPomodoroTick({
    required String roomId,
    required int remainingSeconds,
    required String pomodoroState,
    required String senderId,
  }) async {
    final event = PomodoroSyncEvent(
      roomId: roomId,
      remainingSeconds: remainingSeconds,
      pomodoroState: pomodoroState,
      senderId: senderId,
      timestamp: DateTime.now(),
    );
    await _presenceClient.broadcastPomodoroTick(event);
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
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) {
    return _presenceClient.watchParticipants(roomId);
  }

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) {
    return _presenceClient.watchPomodoroSync(roomId);
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
