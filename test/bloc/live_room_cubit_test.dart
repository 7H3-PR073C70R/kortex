import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/client/ephemeral_presence_client.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/community/domain/repositories/ephemeral_room_repository.dart';
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
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPosts({
    String? track,
  }) async => const Right([]);

  @override
  Future<Either<Failure, ForumPostEntity>> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

  @override
  Future<Either<Failure, ForumReplyEntity>> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) async => const Left(ServerFailure(message: 'Unimplemented'));

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

  Future<void> dispose() async {
    await _roomController.close();
  }
}

class MockEphemeralRoomRepository implements EphemeralRoomRepository {
  final _participantsController =
      StreamController<List<EphemeralParticipant>>.broadcast();
  final _syncController = StreamController<PomodoroSyncEvent>.broadcast();

  final List<EphemeralParticipant> participants = [];
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

  @override
  Future<void> joinRoomPresence({
    required String roomId,
    required String userId,
    required String displayName,
    required String avatarUrl,
  }) async {
    participants.add(
      EphemeralParticipant(
        userId: userId,
        displayName: displayName,
        avatarUrl: avatarUrl,
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

  Future<void> dispose() async {
    await _participantsController.close();
    await _syncController.close();
  }
}

void main() {
  group('LiveRoomCubit Realtime Broadcast & Handshake Test Suite', () {
    late MockCommunityRepository mockCommunityRepo;
    late MockEphemeralRoomRepository mockEphemeralRepo;

    const initialRoom = StudyRoomEntity(
      id: 'room-math-201',
      title: 'Advanced Calculus Focus Hub',
      subject: 'Mathematics',
    );

    setUp(() {
      mockCommunityRepo = MockCommunityRepository();
      mockEphemeralRepo = MockEphemeralRoomRepository();
    });

    tearDown(() async {
      await mockCommunityRepo.dispose();
      await mockEphemeralRepo.dispose();
    });

    test('initial state initializes timer, joins ephemeral presence', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      expect(cubit.state.remainingSeconds, equals(1500));
      expect(cubit.state.room.title, equals('Advanced Calculus Focus Hub'));
      expect(mockEphemeralRepo.participants.length, equals(1));

      await cubit.close();
    });

    test('toggleHandRaise toggles state and broadcasts event', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
        currentUserId: 'user-adeola',
        currentUserName: 'Adeola',
      );

      expect(cubit.state.isHandRaised, isFalse);

      cubit.toggleHandRaise();
      expect(cubit.state.isHandRaised, isTrue);
      expect(mockEphemeralRepo.handRaised, isTrue);

      await cubit.close();
    });

    test('sync event from peer corrects clock drift (>3 seconds)', () async {
      final cubit = LiveRoomCubit(
        initialRoom: initialRoom,
        repository: mockCommunityRepo,
        ephemeralRepository: mockEphemeralRepo,
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
