import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';

class MockCommunityRepository implements CommunityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final StreamController<StudyRoomEntity> _roomController =
      StreamController<StudyRoomEntity>.broadcast();

  @override
  Stream<StudyRoomEntity> watchStudyRoom(String roomId) =>
      _roomController.stream;

  @override
  Future<Either<Failure, String>> getLiveKitToken({
    required String roomId,
    required String userId,
  }) async {
    return const Right('mock_livekit_token');
  }

  Future<void> dispose() async {
    await _roomController.close();
  }
}

class MockEphemeralRepository implements EphemeralRoomRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final StreamController<List<EphemeralParticipant>> participantsCtrl =
      StreamController<List<EphemeralParticipant>>.broadcast();
  final StreamController<PomodoroSyncEvent> pomodoroCtrl =
      StreamController<PomodoroSyncEvent>.broadcast();
  final StreamController<WhiteboardStroke> whiteboardCtrl =
      StreamController<WhiteboardStroke>.broadcast();
  final StreamController<void> whiteboardClearCtrl =
      StreamController<void>.broadcast();
  final StreamController<RoomChatMessage> chatCtrl =
      StreamController<RoomChatMessage>.broadcast();

  final List<Map<String, dynamic>> broadcastAwayCalls = [];

  @override
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
    String? activeGoal,
  }) async {}

  final List<Map<String, dynamic>> broadcastGoalCalls = [];

  @override
  Future<void> broadcastGoal({
    required String roomId,
    required String userId,
    required String? goal,
  }) async {
    broadcastGoalCalls.add({
      'roomId': roomId,
      'userId': userId,
      'goal': goal,
    });
  }

  @override
  Future<void> leaveRoomPresence(String roomId) async {}

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) =>
      participantsCtrl.stream;

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) =>
      pomodoroCtrl.stream;

  @override
  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId) =>
      whiteboardCtrl.stream;

  @override
  Stream<void> watchWhiteboardClear(String roomId) =>
      whiteboardClearCtrl.stream;

  @override
  Stream<RoomChatMessage> watchChatMessages(String roomId) => chatCtrl.stream;

  @override
  Future<void> broadcastAwayState({
    required String roomId,
    required String userId,
    required bool isAway,
  }) async {
    broadcastAwayCalls.add({
      'roomId': roomId,
      'userId': userId,
      'isAway': isAway,
    });
  }

  @override
  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  }) async {}

  @override
  Future<Either<Failure, void>> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async {
    return const Right(null);
  }

  Future<void> dispose() async {
    await participantsCtrl.close();
    await pomodoroCtrl.close();
    await whiteboardCtrl.close();
    await whiteboardClearCtrl.close();
    await chatCtrl.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCommunityRepository mockRepo;
  late MockEphemeralRepository mockEphemeral;
  late StudyRoomEntity testRoom;

  setUp(() {
    mockRepo = MockCommunityRepository();
    mockEphemeral = MockEphemeralRepository();
    testRoom = const StudyRoomEntity(
      id: 'room_shadow_1',
      title: 'Calculus Silent Focus',
      subject: 'MATH201',
      category: 'Engineering',
    );
  });

  tearDown(() async {
    await mockRepo.dispose();
    await mockEphemeral.dispose();
  });

  test('Local user away state toggles presence and broadcasts to room', () async {
    final cubit = LiveRoomCubit(
      initialRoom: testRoom,
      repository: mockRepo,
      ephemeralRepository: mockEphemeral,
      currentUserId: 'user_test_1',
      currentUserName: 'Ade',
    );

    expect(cubit.state.isLocalUserAway, false);

    await cubit.setLocalAwayState(isAway: true);
    expect(cubit.state.isLocalUserAway, true);
    expect(mockEphemeral.broadcastAwayCalls.length, 1);
    expect(mockEphemeral.broadcastAwayCalls.first['isAway'], true);
    expect(cubit.state.recentActivityTicker.first, contains('stepped away'));

    await cubit.setLocalAwayState(isAway: false);
    expect(cubit.state.isLocalUserAway, false);
    expect(mockEphemeral.broadcastAwayCalls.length, 2);
    expect(mockEphemeral.broadcastAwayCalls.last['isAway'], false);
    expect(cubit.state.recentActivityTicker.first, contains('Welcome back'));

    await cubit.close();
  });

  test('Setting and prompting micro-goal updates cubit state and broadcasts to peers', () async {
    final cubit = LiveRoomCubit(
      initialRoom: testRoom,
      repository: mockRepo,
      ephemeralRepository: mockEphemeral,
      currentUserId: 'user_test_1',
      currentUserName: 'Ade',
    )..updateActiveGoal('Solve 10 integrals');

    expect(cubit.state.activeGoal, 'Solve 10 integrals');
    expect(mockEphemeral.broadcastGoalCalls.length, 1);
    expect(mockEphemeral.broadcastGoalCalls.first['goal'], 'Solve 10 integrals');
    expect(mockEphemeral.broadcastGoalCalls.first['userId'], 'user_test_1');

    cubit.promptGoalVerification();
    expect(cubit.state.showGoalVerificationModal, true);

    cubit.dismissGoalVerification();
    expect(cubit.state.showGoalVerificationModal, false);

    await cubit.close();
  });

  test('Verifying micro-goal marks achievement and awards XP', () async {
    final cubit = LiveRoomCubit(
      initialRoom: testRoom,
      repository: mockRepo,
      ephemeralRepository: mockEphemeral,
      currentUserId: 'user_test_1',
      currentUserName: 'Ade',
    )..verifyMicroGoal(completed: true, goal: 'Solve 10 integrals');

    expect(cubit.state.isGoalAchieved, true);
    expect(cubit.state.recentActivityTicker.first, contains('Micro-Goal Achieved'));
    expect(cubit.state.lastReactionEmoji, '🎉');

    await cubit.close();
  });

  test('Syllabot AI Virtual Study Partner activates for solo scholars', () async {
    final cubit = LiveRoomCubit(
      initialRoom: testRoom,
      repository: mockRepo,
      ephemeralRepository: mockEphemeral,
      currentUserId: 'user_test_1',
      currentUserName: 'Ade',
    );

    // Provide initial presence with only the local user
    mockEphemeral.participantsCtrl.add([
      const EphemeralParticipant(
        userId: 'user_test_1',
        displayName: 'Ade',
        avatarUrl: '',
      ),
    ]);

    await pumpEventQueue();

    // Wait for buddy check timer
    await Future<void>.delayed(const Duration(milliseconds: 4100));

    expect(cubit.state.isSyllabotBuddyActive, true);
    expect(
      cubit.state.ephemeralParticipants.any((p) => p.isAiBuddy),
      true,
    );
    expect(
      cubit.state.recentActivityTicker.any((t) => t.contains('Syllabot joined as your study buddy')),
      true,
    );

    await cubit.close();
  });
}
