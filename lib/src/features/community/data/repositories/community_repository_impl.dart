import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(this._remoteDataSource);

  final CommunityRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<StudyRoomEntity>>> fetchStudyRooms({
    String? category,
  }) {
    return _remoteDataSource
        .fetchStudyRooms(category: category)
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Stream<StudyRoomEntity> watchStudyRoom(String roomId) {
    return _remoteDataSource.watchStudyRoom(roomId).map((m) => m.toEntity());
  }

  @override
  Future<Either<Failure, StudyRoomEntity>> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
  }) {
    return _remoteDataSource
        .createStudyRoom(
          title: title,
          subject: subject,
          category: category,
          pomodoroMinutes: pomodoroMinutes,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPosts({
    String? track,
  }) {
    return _remoteDataSource
        .fetchForumPosts(track: track)
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, ForumPostEntity>> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  }) {
    return _remoteDataSource
        .createForumPost(
          title: title,
          content: content,
          track: track,
          latexContent: latexContent,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, ForumReplyEntity>> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) {
    return _remoteDataSource
        .replyToForumPost(
          postId: postId,
          content: content,
          latexContent: latexContent,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<SharedDeckEntity>>> fetchSharedDecks({
    String? subject,
  }) {
    return _remoteDataSource
        .fetchSharedDecks(subject: subject)
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, SharedDeckEntity>> publishDeckToMarketplace({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
  }) {
    return _remoteDataSource
        .publishDeck(
          title: title,
          subject: subject,
          description: description,
          category: category,
          totalCards: totalCards,
          cardsJson: cardsJson,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, DeckEntity>> cloneSharedDeck(
    String sharedDeckId,
  ) {
    return _remoteDataSource.cloneSharedDeck(sharedDeckId).then((result) {
      final newDeckId =
          result['new_deck_id'] as String? ?? 'cloned_$sharedDeckId';
      return DeckEntity(
        id: newDeckId,
        title: 'Cloned Deck',
        subject: 'Community Resource',
        totalCards: (result['cloned_cards_count'] as num?)?.toInt() ?? 10,
        dueCards: (result['cloned_cards_count'] as num?)?.toInt() ?? 10,
        masteryRate: 0,
        category: 'Community',
        description: 'Cloned from Community Marketplace',
      );
    }).makeRequest();
  }

  @override
  Stream<List<LeaderboardEntryEntity>> streamLeaderboards({String? track}) {
    return _remoteDataSource
        .streamLeaderboards(track: track)
        .map(
          (models) => models.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<Either<Failure, List<LeaderboardEntryEntity>>> fetchLeaderboards({
    String? track,
  }) {
    return _remoteDataSource
        .fetchLeaderboards(track: track)
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, StudyCommunityEntity>> autoProvisionCommunity({
    required String courseCode,
    required String title,
    String? department,
  }) {
    return _remoteDataSource
        .autoProvisionCommunity(
          courseCode: courseCode,
          title: title,
          department: department,
        )
        .makeRequest();
  }

  @override
  Future<Either<Failure, StudyCommunityEntity>> fetchCourseCommunityStats(
    String courseCode,
  ) {
    return _remoteDataSource
        .fetchCourseCommunityStats(courseCode)
        .makeRequest();
  }
}
