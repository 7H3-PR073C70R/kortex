import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/data/repositories/ephemeral_room_repository_impl.dart';

class FakeEphemeralPresenceClient implements EphemeralPresenceClient {
  final _participantsController =
      StreamController<List<EphemeralParticipant>>.broadcast();
  final _pomodoroController = StreamController<PomodoroSyncEvent>.broadcast();

  final _whiteboardStrokeController =
      StreamController<WhiteboardStroke>.broadcast();
  final _whiteboardClearController = StreamController<void>.broadcast();
  final _chatMessageController = StreamController<RoomChatMessage>.broadcast();

  final List<EphemeralParticipant> joinedParticipants = [];
  final List<PomodoroSyncEvent> broadcastedTicks = [];
  final List<WhiteboardStroke> broadcastedStrokes = [];
  final List<RoomChatMessage> broadcastedMessages = [];
  bool whiteboardCleared = false;
  bool handRaised = false;
  bool isMuted = true;
  int recordedSessions = 0;

  String? lastBroadcastGoal;

  @override
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
    String? activeGoal,
  }) async {
    final participant = EphemeralParticipant(
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      activeGoal: activeGoal,
    );
    joinedParticipants.add(participant);
    _participantsController.add(joinedParticipants);
  }

  @override
  Future<void> leaveRoomPresence(String roomId) async {
    joinedParticipants.clear();
    _participantsController.add([]);
  }

  @override
  Future<void> broadcastGoal({
    required String roomId,
    required String userId,
    required String? goal,
  }) async {
    lastBroadcastGoal = goal;
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
    broadcastedTicks.add(event);
    _pomodoroController.add(event);
  }

  @override
  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  }) async {
    handRaised = isHandRaised;
  }

  @override
  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  }) async {
    this.isMuted = isMuted;
  }

  bool isAway = false;

  @override
  Future<void> broadcastAwayState({
    required String roomId,
    required String userId,
    required bool isAway,
  }) async {
    this.isAway = isAway;
  }

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) {
    return _participantsController.stream;
  }

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) {
    return _pomodoroController.stream;
  }

  @override
  Future<void> broadcastWhiteboardStroke({
    required String roomId,
    required WhiteboardStroke stroke,
  }) async {
    broadcastedStrokes.add(stroke);
    _whiteboardStrokeController.add(stroke);
  }

  @override
  Future<void> broadcastWhiteboardClear({required String roomId}) async {
    whiteboardCleared = true;
    _whiteboardClearController.add(null);
  }

  @override
  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId) {
    return _whiteboardStrokeController.stream;
  }

  @override
  Stream<void> watchWhiteboardClear(String roomId) {
    return _whiteboardClearController.stream;
  }

  @override
  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  }) async {
    broadcastedMessages.add(message);
    _chatMessageController.add(message);
  }

  @override
  Stream<RoomChatMessage> watchChatMessages(String roomId) {
    return _chatMessageController.stream;
  }

  @override
  Future<void> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async {
    recordedSessions++;
  }

  Future<void> dispose() async {
    await _participantsController.close();
    await _pomodoroController.close();
    await _whiteboardStrokeController.close();
    await _whiteboardClearController.close();
    await _chatMessageController.close();
  }
}

void main() {
  group('EphemeralRoomRepository Presence & Broadcast Test Suite', () {
    late FakeEphemeralPresenceClient fakePresenceClient;
    late EphemeralRoomRepositoryImpl repository;

    setUp(() {
      fakePresenceClient = FakeEphemeralPresenceClient();
      repository = EphemeralRoomRepositoryImpl(
        presenceClient: fakePresenceClient,
      );
    });

    tearDown(() async {
      await fakePresenceClient.dispose();
    });

    test(
      'joinRoomPresence delegates to presence client with participant model',
      () async {
        await repository.joinRoomPresence(
          roomId: 'room-101',
          userId: 'user-adeola',
          displayName: 'Adeola',
          avatarUrl: 'https://avatar.com/adeola.png',
        );

        expect(fakePresenceClient.joinedParticipants.length, equals(1));
        expect(
          fakePresenceClient.joinedParticipants.first.displayName,
          equals('Adeola'),
        );
      },
    );

    test(
      'broadcastPomodoroTick propagates timer sync event without DB write',
      () async {
        await repository.broadcastPomodoroTick(
          roomId: 'room-101',
          remainingSeconds: 1200,
          pomodoroState: 'focusing',
          senderId: 'user-adeola',
        );

        expect(fakePresenceClient.broadcastedTicks.length, equals(1));
        expect(
          fakePresenceClient.broadcastedTicks.first.remainingSeconds,
          equals(1200),
        );
        expect(
          fakePresenceClient.broadcastedTicks.first.pomodoroState,
          equals('focusing'),
        );
      },
    );

    test('broadcastHandRaise updates participant raise state', () async {
      await repository.broadcastHandRaise(
        roomId: 'room-101',
        userId: 'user-adeola',
        isHandRaised: true,
      );

      expect(fakePresenceClient.handRaised, isTrue);
    });

    test('broadcastAwayState updates participant away state', () async {
      await repository.broadcastAwayState(
        roomId: 'room-101',
        userId: 'user-adeola',
        isAway: true,
      );

      expect(fakePresenceClient.isAway, isTrue);
    });
  });
}
