import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
import 'package:kortex/src/features/community/domain/services/livekit_audio_service.dart';
import 'package:kortex/src/features/community/presentation/bloc/live_room_cubit.dart';

class MockLiveKitAudioService implements LiveKitAudioService {
  bool _isMicEnabled = false;
  bool _isConnected = false;

  final StreamController<Set<String>> _speakersController =
      StreamController<Set<String>>.broadcast();
  final StreamController<bool> _micStateController =
      StreamController<bool>.broadcast();
  final StreamController<LiveAudioConnectionState> _connStateController =
      StreamController<LiveAudioConnectionState>.broadcast();

  bool? lastSetMicEnabled;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get isMicrophoneEnabled => _isMicEnabled;

  @override
  Stream<LiveAudioConnectionState> get connectionStateStream =>
      _connStateController.stream;

  @override
  Stream<bool> get microphoneStateStream => _micStateController.stream;

  @override
  Stream<Set<String>> get speakingParticipantsStream =>
      _speakersController.stream;

  @override
  Future<void> connect({
    required String url,
    required String token,
    required String roomId,
    required String userId,
  }) async {
    _isConnected = true;
    if (!_connStateController.isClosed) {
      _connStateController.add(LiveAudioConnectionState.connected);
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _isMicEnabled = false;
    if (!_connStateController.isClosed) {
      _connStateController.add(LiveAudioConnectionState.disconnected);
    }
  }

  @override
  Future<void> setMicrophoneEnabled({required bool enabled}) async {
    lastSetMicEnabled = enabled;
    _isMicEnabled = enabled;
    if (!_micStateController.isClosed) {
      _micStateController.add(enabled);
    }
  }

  void simulateHardwareMicState({required bool enabled}) {
    _isMicEnabled = enabled;
    if (!_micStateController.isClosed) {
      _micStateController.add(enabled);
    }
  }

  Future<void> dispose() async {
    await _speakersController.close();
    await _micStateController.close();
    await _connStateController.close();
  }
}

class MockEphemeralRoomRepository implements EphemeralRoomRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  final List<Map<String, dynamic>> broadcastMuteCalls = [];
  final StreamController<List<EphemeralParticipant>> _participantsCtrl =
      StreamController<List<EphemeralParticipant>>.broadcast();

  @override
  Future<void> broadcastMuteState({
    required String roomId,
    required String userId,
    required bool isMuted,
  }) async {
    broadcastMuteCalls.add({
      'roomId': roomId,
      'userId': userId,
      'isMuted': isMuted,
    });
  }

  @override
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
  }) async {}

  @override
  Future<void> leaveRoomPresence(String roomId) async {}

  @override
  Stream<List<EphemeralParticipant>> watchParticipants(String roomId) =>
      _participantsCtrl.stream;

  @override
  Stream<PomodoroSyncEvent> watchPomodoroSync(String roomId) =>
      const Stream.empty();

  @override
  Stream<WhiteboardStroke> watchWhiteboardStrokes(String roomId) =>
      const Stream.empty();

  @override
  Stream<void> watchWhiteboardClear(String roomId) => const Stream.empty();

  final List<RoomChatMessage> sentChatMessages = [];

  @override
  Future<void> broadcastChatMessage({
    required String roomId,
    required RoomChatMessage message,
  }) async {
    sentChatMessages.add(message);
  }

  @override
  Stream<RoomChatMessage> watchChatMessages(String roomId) =>
      const Stream.empty();

  @override
  Future<Either<Failure, void>> recordCompletedPomodoroSession({
    required String userId,
    required String roomId,
    required int durationMinutes,
    required String subject,
  }) async =>
      const Right(null);

  Future<void> dispose() async {
    await _participantsCtrl.close();
  }
}

class MockCommunityRepository implements CommunityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Either<Failure, String>> getLiveKitToken({
    required String roomId,
    required String userId,
  }) async =>
      const Right('mock-livekit-jwt-token');

  @override
  Stream<StudyRoomEntity> watchStudyRoom(String roomId) => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLiveKitAudioService mockAudioService;
  late MockEphemeralRoomRepository mockEphemeralRepo;
  late MockCommunityRepository mockCommunityRepo;
  late StudyRoomEntity testRoom;

  setUp(() {
    mockAudioService = MockLiveKitAudioService();
    mockEphemeralRepo = MockEphemeralRoomRepository();
    mockCommunityRepo = MockCommunityRepository();

    testRoom = const StudyRoomEntity(
      id: 'room-101',
      title: 'Neurobiology Focus Room',
      subject: 'Medicine',
      category: 'STEM',
      activeParticipantsCount: 4,
    );
  });

  tearDown(() async {
    await mockAudioService.dispose();
    await mockEphemeralRepo.dispose();
  });

  group('Live Study Room Mic Toggle & State Synchronization Tests', () {
    test('Initial room state starts muted (isMuted = true)', () async {
      final cubit = LiveRoomCubit(
        initialRoom: testRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-ade',
        currentUserName: 'Adekunle',
      );

      expect(cubit.state.isMuted, isTrue);
      await cubit.close();
    });

    test(
        'Toggling mic mute un-mutes user, activates audio track, and broadcasts state',
        () async {
      final cubit = LiveRoomCubit(
        initialRoom: testRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-ade',
        currentUserName: 'Adekunle',
      );

      // Initial state is muted
      expect(cubit.state.isMuted, isTrue);

      // User turns mic ON (unmute)
      cubit.toggleMicMute();

      expect(cubit.state.isMuted, isFalse);
      expect(mockAudioService.lastSetMicEnabled, isTrue);

      // Check ephemeral participants list has updated user state
      final userParticipant = cubit.state.ephemeralParticipants
          .firstWhere((p) => p.userId == 'user-ade');
      expect(userParticipant.isMuted, isFalse);

      // Check broadcast was dispatched to peers
      expect(mockEphemeralRepo.broadcastMuteCalls, isNotEmpty);
      expect(mockEphemeralRepo.broadcastMuteCalls.last, {
        'roomId': 'room-101',
        'userId': 'user-ade',
        'isMuted': false,
      });

      await cubit.close();
    });

    test('Toggling mic mute twice returns user to muted state', () async {
      final cubit = LiveRoomCubit(
        initialRoom: testRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-ade',
        currentUserName: 'Adekunle',
      )..toggleMicMute();

      expect(cubit.state.isMuted, isFalse);

      // Mute again
      cubit.toggleMicMute();
      expect(cubit.state.isMuted, isTrue);
      expect(mockAudioService.lastSetMicEnabled, isFalse);

      final userParticipant = cubit.state.ephemeralParticipants
          .firstWhere((p) => p.userId == 'user-ade');
      expect(userParticipant.isMuted, isTrue);

      expect(mockEphemeralRepo.broadcastMuteCalls.last, {
        'roomId': 'room-101',
        'userId': 'user-ade',
        'isMuted': true,
      });

      await cubit.close();
    });

    test(
        'Hardware mic stream event synchronizes cubit state and participants',
        () async {
      final cubit = LiveRoomCubit(
        initialRoom: testRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-ade',
        currentUserName: 'Adekunle',
      )..toggleMicMute();

      expect(cubit.state.isMuted, isFalse);

      // Simulate system revoking mic permission or muting via hardware switch
      mockAudioService.simulateHardwareMicState(enabled: false);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.isMuted, isTrue);
      final userParticipant = cubit.state.ephemeralParticipants
          .firstWhere((p) => p.userId == 'user-ade');
      expect(userParticipant.isMuted, isTrue);

      // Check broadcast was sent so peers are informed
      expect(mockEphemeralRepo.broadcastMuteCalls.last['isMuted'], isTrue);

      await cubit.close();
    });

    test('logCardReviewed increments sprint count and updates ticker', () async {
      final cubit = LiveRoomCubit(
        initialRoom: testRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-ade',
        currentUserName: 'Adekunle',
      );

      expect(cubit.state.cardsReviewedInSprint, 0);

      cubit.logCardReviewed(5);

      expect(cubit.state.cardsReviewedInSprint, 5);
      expect(cubit.state.recentActivityTicker.first, contains('5 flashcards'));
      expect(mockEphemeralRepo.sentChatMessages.length, 1);
      expect(mockEphemeralRepo.sentChatMessages.first.text, contains('Reviewed 5 cards'));

      await cubit.close();
    });

    test('triggerMicroReaction sets last emoji and broadcasts reaction', () async {
      final cubit = LiveRoomCubit(
        initialRoom: testRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        audioService: mockAudioService,
        currentUserId: 'user-ade',
        currentUserName: 'Adekunle',
      )..triggerMicroReaction('🔥');

      expect(cubit.state.lastReactionEmoji, '🔥');
      expect(cubit.state.recentActivityTicker.first, contains('You sent 🔥'));
      expect(mockEphemeralRepo.sentChatMessages.length, 1);
      expect(mockEphemeralRepo.sentChatMessages.first.text, '🔥');

      await cubit.close();
    });
  });
}
