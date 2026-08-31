import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/data/repositories/ephemeral_room_repository_impl.dart';

class FakeEphemeralPresenceClient implements EphemeralPresenceClient {
  final _participantsController =
      StreamController<List<EphemeralParticipant>>.broadcast();
  final _pomodoroController =
      StreamController<PomodoroSyncEvent>.broadcast();

  final List<EphemeralParticipant> joinedParticipants = [];
  final List<PomodoroSyncEvent> broadcastedTicks = [];
  bool handRaised = false;

  @override
  Future<void> joinRoomChannel({
    required String roomId,
    required EphemeralParticipant participant,
  }) async {
    joinedParticipants.add(participant);
    _participantsController.add(joinedParticipants);
  }

  @override
  Future<void> leaveRoomChannel(String roomId) async {
    joinedParticipants.clear();
    _participantsController.add([]);
  }

  @override
  Future<void> broadcastPomodoroTick(PomodoroSyncEvent event) async {
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
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) {
    return _participantsController.stream;
  }

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) {
    return _pomodoroController.stream;
  }

  Future<void> dispose() async {
    await _participantsController.close();
    await _pomodoroController.close();
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

    test('joinRoomPresence delegates to presence client with participant model',
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
    });

    test('broadcastPomodoroTick propagates timer sync event without DB write',
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
    });

    test('broadcastHandRaise updates participant raise state', () async {
      await repository.broadcastHandRaise(
        roomId: 'room-101',
        userId: 'user-adeola',
        isHandRaised: true,
      );

      expect(fakePresenceClient.handRaised, isTrue);
    });
  });
}
