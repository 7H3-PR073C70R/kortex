import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

abstract class CommunityRepository {
  /// Fetches all active study rooms.
  Future<Either<Failure, List<StudyRoomEntity>>> fetchStudyRooms({
    String? category,
  });

  /// Joins a live study room and listens for synchronized Pomodoro updates.
  Stream<StudyRoomEntity> watchStudyRoom(String roomId);

  /// Creates a new study room.
  Future<Either<Failure, StudyRoomEntity>> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
    String ambientSoundTrack = 'lofi',
    String? activeGoal,
    bool isSilentFocus = true,
  });

  /// Fetches discussion forum posts filtered by track.
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPosts({
    String? track,
    bool? questionsOnly,
  });

  /// Creates a new forum thread post or peer question.
  Future<Either<Failure, ForumPostEntity>> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
    bool isQuestion = false,
    String syllabusTag = 'General',
  });

  /// Adds a reply to a forum post.
  Future<Either<Failure, ForumReplyEntity>> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  });

  /// Verifies a peer answer and awards solution bounty XP.
  Future<Either<Failure, bool>> verifyForumReply({
    required String postId,
    required String replyId,
  });

  /// Real-time stream of replies for a forum post via WebSocket.
  Stream<List<ForumReplyEntity>> watchForumReplies(String postId);

  /// Fetches micro-accountability Study Circles (pods of 3-6 students).
  Future<Either<Failure, List<StudyCircleEntity>>> fetchStudyCircles({
    String? track,
  });

  /// Joins an existing Study Circle.
  Future<Either<Failure, StudyCircleEntity>> joinStudyCircle(String circleId);

  /// Creates a new Study Circle.
  Future<Either<Failure, StudyCircleEntity>> createStudyCircle({
    required String name,
    required String track,
    int targetWeeklyMinutes = 600,
  });

  /// Fetches community marketplace decks.
  Future<Either<Failure, List<SharedDeckEntity>>> fetchSharedDecks({
    String? subject,
  });

  /// Publishes a personal deck to the community marketplace.
  Future<Either<Failure, SharedDeckEntity>> publishDeckToMarketplace({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
    String syllabusTag = 'General',
  });

  /// Clones a community shared deck into user's private decks and flashcards.
  Future<Either<Failure, DeckEntity>> cloneSharedDeck(String sharedDeckId);

  /// Streams leaderboard rankings across tracks in real time.
  Stream<List<LeaderboardEntryEntity>> streamLeaderboards({String? track});

  /// Fetches snapshot of leaderboard rankings.
  Future<Either<Failure, List<LeaderboardEntryEntity>>> fetchLeaderboards({
    String? track,
  });

  /// Auto-provisions or joins a course/track study community hub.
  Future<Either<Failure, StudyCommunityEntity>> autoProvisionCommunity({
    required String courseCode,
    required String title,
    String? department,
  });

  /// Fetches statistics and active status for a specific course community.
  Future<Either<Failure, StudyCommunityEntity>> fetchCourseCommunityStats(
    String courseCode,
  );

  /// Generates a WebRTC audio access token for LiveKit voice room.
  Future<Either<Failure, String>> getLiveKitToken({
    required String roomId,
    required String userId,
  });
}
