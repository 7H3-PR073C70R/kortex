import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class MockCommunityRepository implements CommunityRepository {
  final _roomController = StreamController<StudyRoomEntity>.broadcast();

  @override
  Stream<StudyRoomEntity> watchStudyRoom(String roomId) =>
      _roomController.stream;

  @override
  Future<Either<Failure, List<StudyRoomEntity>>> fetchStudyRooms({
    String? category,
  }) async => const Right([]);

  @override
  Future<Either<Failure, StudyRoomEntity>> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
    String ambientSoundTrack = 'Lo-Fi Beats',
    String? activeGoal,
    bool isSilentFocus = true,
  }) async => Right(
    StudyRoomEntity(
      id: 'room-new',
      title: title,
      subject: subject,
      pomodoroDurationMinutes: pomodoroMinutes,
      ambientSoundTrack: ambientSoundTrack,
      activeGoal: activeGoal,
      isSilentFocus: isSilentFocus,
    ),
  );

  @override
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPosts({
    String? track,
    bool? questionsOnly,
  }) async => const Right([]);

  @override
  Future<Either<Failure, ForumPostEntity>> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
    bool isQuestion = false,
    String syllabusTag = 'General',
    bool isAnonymous = false,
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, ForumReplyEntity>> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, bool>> verifyForumReply({
    required String postId,
    required String replyId,
  }) async => const Right(true);

  @override
  Future<Either<Failure, List<StudyCircleEntity>>> fetchStudyCircles({
    String? track,
  }) async => const Right([]);

  @override
  Future<Either<Failure, StudyCircleEntity>> createStudyCircle({
    required String name,
    required String track,
    int targetWeeklyMinutes = 600,
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, StudyCircleEntity>> joinStudyCircle(String circleId) async =>
      const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, List<SharedDeckEntity>>> fetchSharedDecks({
    String? subject,
  }) async => const Right([]);

  @override
  Future<Either<Failure, SharedDeckEntity>> publishDeckToMarketplace({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
    String syllabusTag = 'General',
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, DeckEntity>> cloneSharedDeck(
    String sharedDeckId,
  ) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Stream<List<LeaderboardEntryEntity>> streamLeaderboards({String? track}) =>
      Stream.value([]);

  @override
  Future<Either<Failure, List<LeaderboardEntryEntity>>> fetchLeaderboards({
    String? track,
  }) async => const Right([]);

  @override
  Future<Either<Failure, StudyCommunityEntity>> autoProvisionCommunity({
    required String courseCode,
    required String title,
    String? department,
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Stream<List<ForumReplyEntity>> watchForumReplies(String postId) =>
      Stream.value([]);

  @override
  Future<Either<Failure, StudyCommunityEntity>> fetchCourseCommunityStats(
    String courseCode,
  ) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, String>> getLiveKitToken({
    required String roomId,
    required String userId,
  }) async => const Right('authenticated_livekit_test_token');

  Future<void> dispose() async {
    await _roomController.close();
  }
}

class MockLiveKitAudioService implements LiveKitAudioService {
  final _speakersController = StreamController<Set<String>>.broadcast();
  final _micController = StreamController<bool>.broadcast();
  final _connController =
      StreamController<LiveAudioConnectionState>.broadcast();

  bool _micEnabled = false;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  bool get isMicrophoneEnabled => _micEnabled;

  @override
  Stream<Set<String>> get speakingParticipantsStream =>
      _speakersController.stream;

  @override
  Stream<bool> get microphoneStateStream => _micController.stream;

  @override
  Stream<LiveAudioConnectionState> get connectionStateStream =>
      _connController.stream;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomId,
    required String userId,
  }) async {
    _connected = true;
    _connController.add(LiveAudioConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _connController.add(LiveAudioConnectionState.disconnected);
  }

  @override
  Future<bool> setMicrophoneEnabled({required bool enabled}) async {
    _micEnabled = enabled;
    _micController.add(enabled);
    return true;
  }

  void emitActiveSpeakers(Set<String> speakers) {
    _speakersController.add(speakers);
  }

  Future<void> dispose() async {
    await _speakersController.close();
    await _micController.close();
    await _connController.close();
  }
}

class MockEphemeralRoomRepository implements EphemeralRoomRepository {
  final _participantsController =
      StreamController<List<EphemeralParticipant>>.broadcast();
  final _syncController = StreamController<PomodoroSyncEvent>.broadcast();
  final _whiteboardStrokeController =
      StreamController<WhiteboardStroke>.broadcast();
  final _whiteboardClearController = StreamController<void>.broadcast();
  final _chatMessageController = StreamController<RoomChatMessage>.broadcast();

  final List<EphemeralParticipant> participants = [];
  final List<WhiteboardStroke> broadcastedStrokes = [];
  final List<RoomChatMessage> broadcastedMessages = [];
  bool whiteboardCleared = false;
  bool handRaised = false;
  bool isMuted = true;
  int completedSessionsRecorded = 0;

  @override
  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  }) async {
    this.isMuted = isMuted;
  }

  bool isAway = false;
  String? lastBroadcastGoal;

  @override
  Future<void> broadcastAwayState({
    required String roomId,
    required String userId,
    required bool isAway,
  }) async {
    this.isAway = isAway;
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
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
    String? activeGoal,
  }) async {
    participants.add(
      EphemeralParticipant(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
        activeGoal: activeGoal,
      ),
    );
    _participantsController.add(participants);
  }

  @override
  Future<void> leaveRoomPresence(String roomId) async {
    participants.clear();
    _participantsController.add([]);
  }

  @override
  Future<void> broadcastPomodoroTick({
    required String roomId,
    required int remainingSeconds,
    required String pomodoroState,
    required String senderId,
  }) async {}

  @override
  Future<void> broadcastHandRaise({
    required String roomId,
    required String userId,
    required bool isHandRaised,
  }) async {
    handRaised = isHandRaised;
  }

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) =>
      _participantsController.stream;

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) =>
      _syncController.stream;

  @override
  Future<void> broadcastWhiteboardStroke({
    required String roomId,
    required WhiteboardStroke stroke,
  }) async {
    broadcastedStrokes.add(stroke);
  }

  @override
  Future<void> broadcastWhiteboardClear({required String roomId}) async {
    whiteboardCleared = true;
  }

  @override
  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId) =>
      _whiteboardStrokeController.stream;

  @override
  Stream<void> watchWhiteboardClear(String roomId) =>
      _whiteboardClearController.stream;

  @override
  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  }) async {
    broadcastedMessages.add(message);
  }

  @override
  Stream<RoomChatMessage> watchChatMessages(String roomId) =>
      _chatMessageController.stream;

  @override
  Future<Either<Failure, void>> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async {
    completedSessionsRecorded++;
    return const Right(null);
  }

  void emitSync(PomodoroSyncEvent event) {
    _syncController.add(event);
  }

  void emitRemoteStroke(WhiteboardStroke stroke) {
    _whiteboardStrokeController.add(stroke);
  }

  void emitRemoteClear() {
    _whiteboardClearController.add(null);
  }

  void emitRemoteChatMessage(RoomChatMessage message) {
    _chatMessageController.add(message);
  }

  Future<void> dispose() async {
    await _participantsController.close();
    await _syncController.close();
    await _whiteboardStrokeController.close();
    await _whiteboardClearController.close();
    await _chatMessageController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('LiveRoomCubit Realtime Broadcast & Handshake Test Suite', () {
    late MockCommunityRepository mockCommunityRepo;
    late MockEphemeralRoomRepository mockEphemeralRepo;
    late MockLiveKitAudioService mockAudioService;

    const initialRoom = StudyRoomEntity(
      id: 'room-math-201',
      title: 'Advanced Calculus Focus Hub',
      subject: 'Mathematics',
    );

    setUp(() {
      mockCommunityRepo = MockCommunityRepository();
      mockEphemeralRepo = MockEphemeralRoomRepository();
      mockAudioService = MockLiveKitAudioService();
    });

    tearDown(() async {
      await mockCommunityRepo.dispose();
      await mockEphemeralRepo.dispose();
      await mockAudioService.dispose();
    });

    test('initial state initializes timer, joins ephemeral presence and connects LiveKit audio', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      expect(cubit.state.remainingSeconds, equals(1500));
      expect(cubit.state.room.title, equals('Advanced Calculus Focus Hub'));
      expect(mockEphemeralRepo.participants.length, equals(1));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(mockAudioService.isConnected, isTrue);
      expect(cubit.state.isAudioConnected, isTrue);

      await cubit.close();
    });

    test('LiveKit active speaker stream updates activeSpeakerIds in state', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      mockAudioService.emitActiveSpeakers({'user-peer-1', 'user-peer-2'});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.activeSpeakerIds, contains('user-peer-1'));
      expect(cubit.state.activeSpeakerIds, contains('user-peer-2'));

      await cubit.close();
    });

    test('toggleMicMute communicates with LiveKit audio service and broadcasts presence', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      expect(cubit.state.isMuted, isTrue);

      await cubit.toggleMicMute();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.isMuted, isFalse);
      expect(mockAudioService.isMicrophoneEnabled, isTrue);
      expect(mockEphemeralRepo.isMuted, isFalse);

      await cubit.close();
    });

    test('toggleHandRaise toggles state and broadcasts event', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      expect(cubit.state.isHandRaised, isFalse);

      cubit.toggleHandRaise();
      expect(cubit.state.isHandRaised, isTrue);
      expect(mockEphemeralRepo.handRaised, isTrue);

      await cubit.close();
    });

    test('switchViewMode toggles between stage and whiteboard modes', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      expect(cubit.state.activeViewMode, equals(RoomViewMode.stage));

      cubit.switchViewMode(RoomViewMode.whiteboard);
      expect(cubit.state.activeViewMode, equals(RoomViewMode.whiteboard));

      cubit.switchViewMode(RoomViewMode.stage);
      expect(cubit.state.activeViewMode, equals(RoomViewMode.stage));

      await cubit.close();
    });

    test('addWhiteboardStroke broadcasts stroke and updates local state', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      const stroke = WhiteboardStroke(
        id: 'stroke-1',
        points: [WhiteboardPoint(x: 10, y: 20), WhiteboardPoint(x: 15, y: 25)],
        colorHex: 0xFFFFFFFF,
        strokeWidth: 3,
        userId: 'user-adeola',
        userName: 'Adeola',
      );

      cubit.addWhiteboardStroke(stroke);

      expect(cubit.state.whiteboardStrokes.length, equals(1));
      expect(cubit.state.whiteboardStrokes.first.id, equals('stroke-1'));
      expect(cubit.state.whiteboardRedoStack, isEmpty);
      expect(mockEphemeralRepo.broadcastedStrokes.length, equals(1));

      // Test Undo
      cubit.undoWhiteboardStroke();
      expect(cubit.state.whiteboardStrokes, isEmpty);
      expect(cubit.state.whiteboardRedoStack.length, equals(1));
      expect(cubit.state.whiteboardRedoStack.first.id, equals('stroke-1'));

      // Test Redo
      cubit.redoWhiteboardStroke();
      expect(cubit.state.whiteboardStrokes.length, equals(1));
      expect(cubit.state.whiteboardRedoStack, isEmpty);
      expect(mockEphemeralRepo.broadcastedStrokes.length, equals(2));

      // Remote stroke received from another user
      const remoteStroke = WhiteboardStroke(
        id: 'stroke-2',
        points: [WhiteboardPoint(x: 50, y: 50)],
        colorHex: 0xFFFF0000,
        strokeWidth: 4,
        userId: 'user-peer',
        userName: 'Peer',
      );
      mockEphemeralRepo.emitRemoteStroke(remoteStroke);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.whiteboardStrokes.length, equals(2));

      // Clear whiteboard clears strokes and redo stack
      cubit.clearWhiteboard();
      expect(cubit.state.whiteboardStrokes, isEmpty);
      expect(cubit.state.whiteboardRedoStack, isEmpty);
      expect(mockEphemeralRepo.whiteboardCleared, isTrue);

      // Test shape and text stroke serialization
      const shapeStroke = WhiteboardStroke(
        id: 'shape-1',
        userId: 'user-adeola',
        userName: 'Adeola',
        colorHex: 0xFF00E5FF,
        strokeWidth: 4,
        points: [WhiteboardPoint(x: 10, y: 10), WhiteboardPoint(x: 100, y: 100)],
        elementType: 'shape',
        shapeType: 'rectangle',
      );
      cubit.addWhiteboardStroke(shapeStroke);
      expect(cubit.state.whiteboardStrokes.last.isShape, isTrue);
      expect(cubit.state.whiteboardStrokes.last.shapeType, equals('rectangle'));

      final shapeJson = shapeStroke.toJson();
      final roundtripShape = WhiteboardStroke.fromJson(shapeJson);
      expect(roundtripShape.isShape, isTrue);
      expect(roundtripShape.shapeType, equals('rectangle'));

      const textStroke = WhiteboardStroke(
        id: 'text-1',
        userId: 'user-adeola',
        userName: 'Adeola',
        colorHex: 0xFFFFFFFF,
        strokeWidth: 2,
        points: [WhiteboardPoint(x: 20, y: 40)],
        elementType: 'text',
        text: 'E = mc^2',
        fontSize: 24,
      );
      cubit.addWhiteboardStroke(textStroke);
      expect(cubit.state.whiteboardStrokes.last.isText, isTrue);
      expect(cubit.state.whiteboardStrokes.last.text, equals('E = mc^2'));

      final textJson = textStroke.toJson();
      final roundtripText = WhiteboardStroke.fromJson(textJson);
      expect(roundtripText.isText, isTrue);
      expect(roundtripText.text, equals('E = mc^2'));
      expect(roundtripText.fontSize, equals(24));

      // Re-add stroke and test remote clear receipt
      mockEphemeralRepo.emitRemoteClear();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(cubit.state.whiteboardStrokes, isEmpty);
      expect(cubit.state.whiteboardRedoStack, isEmpty);

      await cubit.close();
    });

    test('sendChatMessage broadcasts message and remote receipt increments unreadChatCount', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      )..sendChatMessage('Hello classmates!');

      expect(cubit.state.chatMessages.length, equals(1));
      expect(cubit.state.chatMessages.first.text, equals('Hello classmates!'));
      expect(cubit.state.unreadChatCount, equals(0)); // Self message doesn't increment unread
      expect(mockEphemeralRepo.broadcastedMessages.length, equals(1));

      // Receive remote message from peer
      final peerMessage = RoomChatMessage(
        id: 'msg-remote-1',
        senderId: 'user-peer',
        senderName: 'Tunde',
        senderAvatar: '',
        text: 'Let us solve problem 4',
        timestamp: DateTime.now(),
      );
      mockEphemeralRepo.emitRemoteChatMessage(peerMessage);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.chatMessages.length, equals(2));
      expect(cubit.state.unreadChatCount, equals(1));

      // Mark chat as read resets unread count
      cubit.markChatAsRead();
      expect(cubit.state.unreadChatCount, equals(0));

      await cubit.close();
    });

    test('sync event from peer corrects clock drift (>3 seconds)', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      // Peer broadcasts remaining seconds 1450 (difference > 3s from 1500)
      mockEphemeralRepo.emitSync(
        PomodoroSyncEvent(
          roomId: 'room-math-201',
          remainingSeconds: 1450,
          pomodoroState: 'focusing',
          senderId: 'user-peer-123',
          timestamp: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.remainingSeconds, equals(1450));

      await cubit.close();
    });
  });
}
