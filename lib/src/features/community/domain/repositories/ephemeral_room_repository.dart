import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';

abstract class EphemeralRoomRepository {
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
  });

  Future<void> leaveRoomPresence(String roomId);

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

  Stream<List<EphemeralParticipant>> watchParticipants(String roomId);

  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId);

  /// Database persistence handshake executed ONLY on completion/exit of 25-minute Pomodoro block.
  Future<Either<Failure, void>> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  });
}
