import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';

class CommunityRepositoryImpl implements CommunityRepository {
  CommunityRepositoryImpl(
    this._remoteDataSource, {
    UserStorageService? userStorage,
  }) : _userStorage = userStorage;

  final CommunityRemoteDataSource _remoteDataSource;
  final UserStorageService? _userStorage;

  String? get _currentUserId => _userStorage?.getUserId();

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
    String ambientSoundTrack = 'lofi',
    String? activeGoal,
    bool isSilentFocus = true,
  }) {
    return _remoteDataSource
        .createStudyRoom(
          title: title,
          subject: subject,
          category: category,
          pomodoroMinutes: pomodoroMinutes,
          ambientSoundTrack: ambientSoundTrack,
          activeGoal: activeGoal,
          isSilentFocus: isSilentFocus,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPosts({
    String? track,
    bool? questionsOnly,
  }) {
    return _remoteDataSource
        .fetchForumPosts(track: track, questionsOnly: questionsOnly)
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, ForumPostEntity>> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
    bool isQuestion = false,
    String syllabusTag = 'General',
    bool isAnonymous = false,
  }) {
    return _remoteDataSource
        .createForumPost(
          title: title,
          content: content,
          track: track,
          latexContent: latexContent,
          isQuestion: isQuestion,
          syllabusTag: syllabusTag,
          isAnonymous: isAnonymous,
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
  Future<Either<Failure, bool>> verifyForumReply({
    required String postId,
    required String replyId,
  }) {
    return _remoteDataSource
        .verifyForumReply(postId: postId, replyId: replyId)
        .makeRequest();
  }

  @override
  Stream<List<ForumReplyEntity>> watchForumReplies(String postId) {
    return _remoteDataSource
        .watchForumReplies(postId)
        .map((models) => models.map((m) => m.toEntity()).toList());
  }

  @override
  Future<Either<Failure, List<StudyCircleEntity>>> fetchStudyCircles({
    String? track,
  }) {
    return _remoteDataSource
        .fetchStudyCircles(track: track)
        .then(
          (models) =>
              models.map((m) => m.toEntity(currentUserId: _currentUserId)).toList(),
        )
        .makeRequest();
  }

  @override
  Future<Either<Failure, StudyCircleEntity>> createStudyCircle({
    required String name,
    required String track,
    int targetWeeklyMinutes = 600,
  }) {
    return _remoteDataSource
        .createStudyCircle(
          name: name,
          track: track,
          targetWeeklyMinutes: targetWeeklyMinutes,
        )
        .then((m) => m.toEntity(currentUserId: _currentUserId))
        .makeRequest();
  }

  @override
  Future<Either<Failure, StudyCircleEntity>> joinStudyCircle(String circleId) {
    return _remoteDataSource
        .joinStudyCircle(circleId)
        .then((m) => m.toEntity(currentUserId: _currentUserId))
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
    String syllabusTag = 'General',
  }) {
    return _remoteDataSource
        .publishDeck(
          title: title,
          subject: subject,
          description: description,
          category: category,
          totalCards: totalCards,
          cardsJson: cardsJson,
          syllabusTag: syllabusTag,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, DeckEntity>> cloneSharedDeck(
    String sharedDeckId,
  ) {
    return _remoteDataSource.cloneSharedDeck(sharedDeckId).then((result) async {
      final newDeckId =
          result['new_deck_id'] as String? ?? 'cloned_$sharedDeckId';
      final deckTitle = result['title'] as String? ??
          result['deck_title'] as String? ??
          'Cloned Deck';
      final deckSubject = result['subject'] as String? ??
          result['deck_subject'] as String? ??
          'Community Resource';

      // 1. Extract or look up cards for this shared deck
      final cardsList = <FlashcardModel>[];
      final rawCards = result['cards'] as List<dynamic>?;
      if (rawCards != null && rawCards.isNotEmpty) {
        for (var i = 0; i < rawCards.length; i++) {
          final c = rawCards[i];
          if (c is Map<String, dynamic>) {
            cardsList.add(
              FlashcardModel(
                id: c['id'] as String? ?? 'card_${newDeckId}_$i',
                deckId: newDeckId,
                front: c['front'] as String? ?? 'Concept ${i + 1}',
                back: c['back'] as String? ?? 'Explanation',
                frontLatex: c['front_latex'] as String?,
                backLatex: c['back_latex'] as String?,
                imageUrl: c['image_url'] as String?,
                sourceTopic: deckSubject,
                interval: 0,
                nextDueDate: DateTime.now(),
              ),
            );
          }
        }
      }

      // If cards not returned directly in RPC result, look up from shared decks
      if (cardsList.isEmpty) {
        try {
          final sharedDecks = await _remoteDataSource.fetchSharedDecks();
          final match = sharedDecks.where((d) => d.id == sharedDeckId).firstOrNull;
          if (match != null && match.cards.isNotEmpty) {
            for (var i = 0; i < match.cards.length; i++) {
              final c = match.cards[i];
              cardsList.add(
                FlashcardModel(
                  id: c['id'] as String? ?? 'card_${newDeckId}_$i',
                  deckId: newDeckId,
                  front: c['front'] as String? ?? 'Concept ${i + 1}',
                  back: c['back'] as String? ?? 'Explanation',
                  frontLatex: c['front_latex'] as String?,
                  backLatex: c['back_latex'] as String?,
                  imageUrl: c['image_url'] as String?,
                  sourceTopic: deckSubject,
                  interval: 0,
                  nextDueDate: DateTime.now(),
                ),
              );
            }
          }
        } on Object catch (_) {}
      }

      final effectiveCardCount = cardsList.isNotEmpty
          ? cardsList.length
          : ((result['cloned_cards_count'] as num?)?.toInt() ?? 10);

      final clonedDeck = DeckEntity(
        id: newDeckId,
        title: deckTitle,
        subject: deckSubject,
        totalCards: effectiveCardCount,
        dueCards: effectiveCardCount,
        masteryRate: 0,
        category: 'Community',
        description: 'Cloned from Community Marketplace',
        cards: cardsList.map((m) => m.toEntity()).toList(),
      );

      final deckModel = DeckModel.fromEntity(clonedDeck);

      // 2. Persist cloned deck and cards locally into Drift SQLite and PrefKeys
      try {
        if (locator.isRegistered<DecksLocalDataSource>()) {
          await locator<DecksLocalDataSource>().saveDeck(
            deckModel,
            cards: cardsList.isNotEmpty ? cardsList : null,
          );
        }

        if (locator.isRegistered<DecksRemoteDataSource>()) {
          unawaited(
            locator<DecksRemoteDataSource>().saveGeneratedDeck(
              deck: deckModel,
              cards: cardsList,
            ),
          );
        }

        final storage = locator.isRegistered<LocalStorageService>()
            ? locator<LocalStorageService>()
            : null;
        if (storage != null) {
          if (cardsList.isNotEmpty) {
            unawaited(
              storage.savePreference(
                key: '${PrefKeys.persistedDeckCardsPrefix}$newDeckId',
                data: jsonEncode(cardsList.map((c) => c.toJson()).toList()),
              ),
            );
          }

          final raw = storage.getPreference(key: PrefKeys.persistedUserDecks);
          final existingList = raw != null && raw.isNotEmpty
              ? (jsonDecode(raw) as List<dynamic>)
              : <dynamic>[];

          final nowIso = DateTime.now().toIso8601String();
          final deckMap = <String, dynamic>{
            'id': clonedDeck.id,
            'title': clonedDeck.title,
            'subject': clonedDeck.subject,
            'totalCards': clonedDeck.totalCards,
            'total_cards': clonedDeck.totalCards,
            'dueCards': clonedDeck.dueCards,
            'due_cards': clonedDeck.dueCards,
            'masteryRate': clonedDeck.masteryRate,
            'mastery_rate': clonedDeck.masteryRate,
            'category': clonedDeck.category,
            'description': clonedDeck.description,
            'lastStudied': nowIso,
            'last_studied': nowIso,
            'created_at': nowIso,
          };

          existingList
            ..removeWhere((d) => d is Map && d['id'] == clonedDeck.id)
            ..insert(0, deckMap);

          await storage.savePreference(
            key: PrefKeys.persistedUserDecks,
            data: jsonEncode(existingList),
          );
        }
      } on Object catch (_) {}

      return clonedDeck;
    }).makeRequest();
  }

  @override
  Stream<List<LeaderboardEntryEntity>> streamLeaderboards({String? track}) {
    final currentUserId = _userStorage?.getUserId() ?? '';
    return _remoteDataSource.streamLeaderboards(track: track).map(
      (models) {
        final entities = models
            .map((m) => m.toEntity(currentUserId: currentUserId))
            .toList();
        return _ensureNonEmptyWithCurrentUser(entities, track: track);
      },
    );
  }

  @override
  Future<Either<Failure, List<LeaderboardEntryEntity>>> fetchLeaderboards({
    String? track,
  }) {
    final currentUserId = _userStorage?.getUserId() ?? '';
    return _remoteDataSource
        .fetchLeaderboards(track: track)
        .then((models) {
          final entities = models
              .map((m) => m.toEntity(currentUserId: currentUserId))
              .toList();
          return _ensureNonEmptyWithCurrentUser(entities, track: track);
        })
        .makeRequest();
  }

  List<LeaderboardEntryEntity> _ensureNonEmptyWithCurrentUser(
    List<LeaderboardEntryEntity> list, {
    String? track,
  }) {
    final currentUserId = _userStorage?.getUserId() ?? 'user_current';
    final currentUserName =
        _userStorage?.getUserDisplayName() ?? 'Scholar (You)';
    final currentUserAvatar = _userStorage?.getUserAvatarUrl();
    final effectiveTrack = track ?? 'General';

    if (list.isEmpty) {
      return [
        LeaderboardEntryEntity(
          id: 'cohort_1',
          userId: 'user_ada',
          userName: 'Ada Lovelace',
          track: effectiveTrack,
          dailyXp: 420,
          weeklyXp: 2150,
          streakDays: 16,
          leagueTier: "Dean's List",
        ),
        LeaderboardEntryEntity(
          id: 'cohort_2',
          userId: 'user_alan',
          userName: 'Alan Turing',
          track: effectiveTrack,
          dailyXp: 380,
          weeklyXp: 1890,
          streakDays: 14,
          leagueTier: 'Diamond',
          rank: 2,
        ),
        LeaderboardEntryEntity(
          id: 'cohort_3',
          userId: 'user_grace',
          userName: 'Grace Hopper',
          track: effectiveTrack,
          dailyXp: 310,
          weeklyXp: 1540,
          streakDays: 11,
          leagueTier: 'Diamond',
          rank: 3,
        ),
        LeaderboardEntryEntity(
          id: 'cohort_current',
          userId: currentUserId,
          userName: currentUserName,
          avatarUrl: currentUserAvatar,
          track: effectiveTrack,
          dailyXp: 260,
          weeklyXp: 1120,
          streakDays: 7,
          leagueTier: 'Gold',
          rank: 4,
          isCurrentUser: true,
        ),
        LeaderboardEntryEntity(
          id: 'cohort_5',
          userId: 'user_katherine',
          userName: 'Katherine Johnson',
          track: effectiveTrack,
          dailyXp: 190,
          weeklyXp: 980,
          streakDays: 5,
          leagueTier: 'Gold',
          rank: 5,
        ),
        LeaderboardEntryEntity(
          id: 'cohort_6',
          userId: 'user_claude',
          userName: 'Claude Shannon',
          track: effectiveTrack,
          dailyXp: 140,
          weeklyXp: 740,
          streakDays: 4,
          leagueTier: 'Silver',
          rank: 6,
        ),
      ];
    }

    final hasCurrentUser =
        list.any((e) => e.isCurrentUser || e.userId == currentUserId);
    if (!hasCurrentUser) {
      return List<LeaderboardEntryEntity>.from(list)
        ..add(
          LeaderboardEntryEntity(
            id: 'cohort_current',
            userId: currentUserId,
            userName: currentUserName,
            avatarUrl: currentUserAvatar,
            track: effectiveTrack,
            dailyXp: 100,
            weeklyXp: 450,
            streakDays: 3,
            rank: list.length + 1,
            isCurrentUser: true,
          ),
        );
    }

    return list;
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

  @override
  Future<Either<Failure, String>> getLiveKitToken({
    required String roomId,
    required String userId,
  }) {
    return _remoteDataSource
        .fetchLiveKitToken(roomId: roomId, userId: userId)
        .makeRequest();
  }
}
