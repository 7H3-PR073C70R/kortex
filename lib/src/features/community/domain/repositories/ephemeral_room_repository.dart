import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';

abstract class EphemeralRoomRepository {
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
    String? activeGoal,
  });

  Future<void> leaveRoomPresence(String roomId);

  Future<void> broadcastGoal({
    required String roomId,
    required String userId,
    required String? goal,
  });

  Future<void> broadcastPomodoroTick({
    required String roomId,
    required int remainingSeconds,
    required String pomodoroState,
    required String senderId,
  });

  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  });

  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  });

  Future<void> broadcastAwayState({
    required String roomId,
    required String userId,
    required bool isAway,
  });

  Future<void> broadcastWhiteboardStroke({
    required String roomId,
    required WhiteboardStroke stroke,
  });

  Future<void> broadcastWhiteboardClear({required String roomId});

  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  });

  Stream<List<EphemeralParticipant>> watchParticipants(String roomId);

  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId);

  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId);

  Stream<void> watchWhiteboardClear(String roomId);

  Stream<RoomChatMessage> watchChatMessages(String roomId);

  /// Database persistence handshake executed ONLY on completion/exit of 25-minute Pomodoro block.
  Future<Either<Failure, void>> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  });
}
