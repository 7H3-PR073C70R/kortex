import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(this._remoteDataSource);

  final CommunityRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, List<StudyRoomEntity>>> fetchStudyRooms({
    String? category,
  }) async {
    try {
      final models = await _remoteDataSource.fetchStudyRooms(
        category: category,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
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
  }) async {
    try {
      final model = await _remoteDataSource.createStudyRoom(
        title: title,
        subject: subject,
        category: category,
        pomodoroMinutes: pomodoroMinutes,
      );
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPosts({
    String? track,
  }) async {
    try {
      final models = await _remoteDataSource.fetchForumPosts(track: track);
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ForumPostEntity>> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
  }) async {
    try {
      final model = await _remoteDataSource.createForumPost(
        title: title,
        content: content,
        track: track,
        latexContent: latexContent,
      );
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ForumReplyEntity>> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) async {
    try {
      final model = await _remoteDataSource.replyToForumPost(
        postId: postId,
        content: content,
        latexContent: latexContent,
      );
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SharedDeckEntity>>> fetchSharedDecks({
    String? subject,
  }) async {
    try {
      final models = await _remoteDataSource.fetchSharedDecks(
        subject: subject,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SharedDeckEntity>> publishDeckToMarketplace({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
  }) async {
    try {
      final model = await _remoteDataSource.publishDeck(
        title: title,
        subject: subject,
        description: description,
        category: category,
        totalCards: totalCards,
        cardsJson: cardsJson,
      );
      return Right(model.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, DeckEntity>> cloneSharedDeck(
    String sharedDeckId,
  ) async {
    try {
      final result = await _remoteDataSource.cloneSharedDeck(sharedDeckId);
      final newDeckId =
          result['new_deck_id'] as String? ?? 'cloned_$sharedDeckId';
      final clonedDeck = DeckEntity(
        id: newDeckId,
        title: 'Cloned Deck',
        subject: 'Community Resource',
        totalCards: (result['cloned_cards_count'] as num?)?.toInt() ?? 10,
        dueCards: (result['cloned_cards_count'] as num?)?.toInt() ?? 10,
        masteryRate: 0,
        category: 'Community',
        description: 'Cloned from Community Marketplace',
      );
      return Right(clonedDeck);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<List<LeaderboardEntryEntity>> streamLeaderboards({String? track}) {
    return _remoteDataSource.streamLeaderboards(track: track).map(
          (models) => models.map((m) => m.toEntity()).toList(),
        );
  }

  @override
  Future<Either<Failure, List<LeaderboardEntryEntity>>> fetchLeaderboards({
    String? track,
  }) async {
    try {
      final models = await _remoteDataSource.fetchLeaderboards(track: track);
      return Right(models.map((m) => m.toEntity()).toList());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
