import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/entities/study_community_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';

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
    String? sortFilter,
    String? searchQuery,
    int limit = 15,
    int offset = 0,
    DateTime? cursorCreatedAt,
    String? cursorId,
  }) {
    return _remoteDataSource
        .fetchForumPosts(
          track: track,
          questionsOnly: questionsOnly,
          sortFilter: sortFilter,
          searchQuery: searchQuery,
          limit: limit,
          offset: offset,
          cursorCreatedAt: cursorCreatedAt,
          cursorId: cursorId,
        )
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<ForumPostEntity>>> fetchForumPostsKeyset({
    String? track,
    DateTime? cursorCreatedAt,
    String? cursorId,
    int limit = 15,
    String sortFilter = 'latest',
    String? searchQuery,
    bool questionsOnly = false,
  }) {
    return _remoteDataSource
        .fetchForumPostsKeyset(
          track: track,
          cursorCreatedAt: cursorCreatedAt,
          cursorId: cursorId,
          limit: limit,
          sortFilter: sortFilter,
          searchQuery: searchQuery,
          questionsOnly: questionsOnly,
        )
        .then((models) => models.map((m) => m.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<
    Either<Failure, ({ForumPostEntity post, List<ForumReplyEntity> replies})>
  >
  fetchForumThreadTree({
    required String postId,
    int limit = 20,
    int subReplyLimit = 5,
  }) {
    return _remoteDataSource
        .fetchForumThreadTree(
          postId: postId,
          limit: limit,
          subReplyLimit: subReplyLimit,
        )
        .then((data) {
          if (data == null || data['post'] == null) {
            throw Exception('Forum thread not found');
          }
          final postModel = ForumPostModel.fromJson(
            data['post'] as Map<String, dynamic>,
          );
          final repliesList = data['replies'] is List
              ? (data['replies'] as List)
              : <dynamic>[];
          final allReplies = <ForumReplyModel>[];
          for (final r in repliesList) {
            if (r is Map<String, dynamic>) {
              allReplies.add(ForumReplyModel.fromJson(r));
              if (r['subReplies'] is List) {
                for (final sr in r['subReplies'] as List) {
                  if (sr is Map<String, dynamic>) {
                    allReplies.add(ForumReplyModel.fromJson(sr));
                  }
                }
              }
            }
          }
          return (
            post: postModel.toEntity(),
            replies: allReplies.map((r) => r.toEntity()).toList(),
          );
        })
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> saveForumSocraticHint({
    required String postId,
    required String hint,
  }) {
    return _remoteDataSource
        .saveForumSocraticHint(postId: postId, hint: hint)
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<ForumReplyEntity>>> fetchForumReplies({
    required String postId,
    String? parentReplyId,
    bool topLevelOnly = false,
    String? sortFilter,
    int limit = 15,
    int offset = 0,
  }) {
    return _remoteDataSource
        .fetchForumReplies(
          postId: postId,
          parentReplyId: parentReplyId,
          topLevelOnly: topLevelOnly,
          sortFilter: sortFilter,
          limit: limit,
          offset: offset,
        )
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
    List<String>? tags,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    String? voiceNoteTranscript,
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
          tags: tags,
          mediaUrls: mediaUrls,
          voiceNoteUrl: voiceNoteUrl,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds,
          voiceNoteTranscript: voiceNoteTranscript,
          isAnonymous: isAnonymous,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, ForumPostEntity>> updateForumPost({
    required String postId,
    String? title,
    String? content,
    String? track,
    String? latexContent,
    List<String>? tags,
    List<String>? mediaUrls,
  }) {
    return _remoteDataSource
        .updateForumPost(
          postId: postId,
          title: title,
          content: content,
          track: track,
          latexContent: latexContent,
          tags: tags,
          mediaUrls: mediaUrls,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> deleteForumPost(String postId) {
    return _remoteDataSource.deleteForumPost(postId).makeRequest();
  }

  @override
  Future<Either<Failure, ForumReplyEntity>> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
    String? parentReplyId,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    String? voiceNoteTranscript,
    bool isAnonymous = false,
  }) {
    return _remoteDataSource
        .replyToForumPost(
          postId: postId,
          content: content,
          latexContent: latexContent,
          parentReplyId: parentReplyId,
          mediaUrls: mediaUrls,
          voiceNoteUrl: voiceNoteUrl,
          voiceNoteDurationSeconds: voiceNoteDurationSeconds,
          voiceNoteTranscript: voiceNoteTranscript,
          isAnonymous: isAnonymous,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, ForumReplyEntity>> updateForumReply({
    required String replyId,
    required String content,
    String? latexContent,
  }) {
    return _remoteDataSource
        .updateForumReply(
          replyId: replyId,
          content: content,
          latexContent: latexContent,
        )
        .then((model) => model.toEntity())
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> deleteForumReply({
    required String replyId,
    required String postId,
  }) {
    return _remoteDataSource
        .deleteForumReply(replyId: replyId, postId: postId)
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> voteForumPost({
    required String postId,
    required int voteDirection,
  }) {
    return _remoteDataSource
        .voteForumPost(postId: postId, voteDirection: voteDirection)
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> voteForumReply({
    required String postId,
    required String replyId,
    required int voteDirection,
  }) {
    return _remoteDataSource
        .voteForumReply(
          postId: postId,
          replyId: replyId,
          voteDirection: voteDirection,
        )
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
          (models) => models
              .map((m) => m.toEntity(currentUserId: _currentUserId))
              .toList(),
        )
        .makeRequest();
  }

  @override
  Stream<List<StudyCircleEntity>> watchStudyCircles({String? track}) {
    return _remoteDataSource.watchStudyCircles(track: track).map(
          (models) => models
              .map((m) => m.toEntity(currentUserId: _currentUserId))
              .toList(),
        );
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
  Future<Either<Failure, StudyCircleEntity>> leaveStudyCircle(String circleId) {
    return _remoteDataSource
        .leaveStudyCircle(circleId)
        .then((m) => m.toEntity(currentUserId: _currentUserId))
        .makeRequest();
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> nudgeStudyCircle(
    String circleId,
  ) {
    return _remoteDataSource.nudgeStudyCircle(circleId).makeRequest();
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> recordPodFocusMinutes({
    required String circleId,
    required int minutes,
    String? activityType,
  }) {
    return _remoteDataSource
        .recordPodFocusMinutes(
          circleId: circleId,
          minutes: minutes,
          activityType: activityType,
        )
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
      final deckTitle =
          result['title'] as String? ??
          result['deck_title'] as String? ??
          'Cloned Deck';
      final deckSubject =
          result['subject'] as String? ??
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
          final match = sharedDecks
              .where((d) => d.id == sharedDeckId)
              .firstOrNull;
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
  Future<Either<Failure, bool>> rateSharedDeck({
    required String sharedDeckId,
    required double rating,
  }) {
    return _remoteDataSource
        .rateSharedDeck(sharedDeckId: sharedDeckId, rating: rating)
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> toggleBookmarkSharedDeck(String sharedDeckId) {
    return _remoteDataSource
        .toggleBookmarkSharedDeck(sharedDeckId)
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<String>>> getBookmarkedSharedDeckIds() {
    return _remoteDataSource.getBookmarkedSharedDeckIds().makeRequest();
  }

  @override
  Stream<List<LeaderboardEntryEntity>> streamLeaderboards({String? track}) {
    final currentUserId = _userStorage?.getUserId() ?? '';
    return _remoteDataSource.streamLeaderboards(track: track).map(
      (models) {
        final entities = models
            .map((m) => m.toEntity(currentUserId: currentUserId))
            .toList();
        return _processLeaderboardList(entities, track: track);
      },
    );
  }

  @override
  Future<Either<Failure, List<LeaderboardEntryEntity>>> fetchLeaderboards({
    String? track,
  }) {
    final currentUserId = _userStorage?.getUserId() ?? '';
    return _remoteDataSource.fetchLeaderboards(track: track).then((models) {
      final entities = models
          .map((m) => m.toEntity(currentUserId: currentUserId))
          .toList();
      return _processLeaderboardList(entities, track: track);
    }).makeRequest();
  }

  /// Tracks the last time we pushed XP to Supabase to prevent spamming.
  DateTime? _lastClaimWeeklyXpTime;

  List<LeaderboardEntryEntity> _processLeaderboardList(
    List<LeaderboardEntryEntity> list, {
    String? track,
  }) {
    final authProfile = locator.isRegistered<AuthBloc>()
        ? locator<AuthBloc>().state.userProfile
        : null;

    final currentUserId = _userStorage?.getUserId() ?? authProfile?.id;

    final userActivity = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>()
        : null;

    // ── Streak: prefer live activity service, fall back to auth profile ──
    final localStreak = userActivity?.getCurrentStreak() ?? 0;
    final liveStreak = math.max(
      authProfile?.streakDays ?? 0,
      localStreak,
    );

    // ── XP: prefer live activity service, fall back to auth profile ─────
    final liveXp = math.max(
      authProfile?.xpPoints ?? 0,
      userActivity?.getXpPoints() ?? 0,
    );

    // ── Track: auth profile → LocalStorage pref → 'General' ─────────────
    final profileTrack = authProfile?.targetTrack.trim();
    String liveTrack;
    if (profileTrack != null && profileTrack.isNotEmpty) {
      liveTrack = profileTrack;
    } else {
      final storedTrack = locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>().getPreference(
              key: PrefKeys.userTargetTrack,
            )
          : null;
      liveTrack =
          (storedTrack != null && storedTrack.trim().isNotEmpty)
          ? storedTrack.trim()
          : 'General';
    }

    final profileName = authProfile?.displayName?.trim();
    final liveDisplayName = (profileName != null && profileName.isNotEmpty)
        ? profileName
        : (_userStorage?.getUserDisplayName() ?? 'Scholar (You)');

    final liveAvatarUrl =
        authProfile?.photoUrl ?? _userStorage?.getUserAvatarUrl();

    // ── Throttled background sync to Supabase (at most every 5 minutes) ──
    final now = DateTime.now();
    final shouldClaim =
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        liveXp > 0 &&
        (_lastClaimWeeklyXpTime == null ||
            now.difference(_lastClaimWeeklyXpTime!) >
                const Duration(minutes: 5));
    if (shouldClaim) {
      _lastClaimWeeklyXpTime = now;
      unawaited(
        _remoteDataSource
            .claimWeeklyXp(xpAmount: liveXp)
            .catchError((_) => <String, dynamic>{}),
      );
    }

    if (list.isEmpty) {
      if (currentUserId != null && currentUserId.isNotEmpty) {
        final trackMatches = track == null ||
            track.isEmpty ||
            track == 'All' ||
            liveTrack.toLowerCase() == track.toLowerCase();

        if (trackMatches) {
          final tier = _calculateLeagueTier(liveXp);
          return [
            LeaderboardEntryEntity(
              id: 'user_$currentUserId',
              userId: currentUserId,
              userName: liveDisplayName,
              avatarUrl: liveAvatarUrl,
              track: liveTrack,
              weeklyXp: liveXp,
              streakDays: liveStreak > 0 ? liveStreak : 1,
              leagueTier: tier,
              isCurrentUser: true,
            ),
          ];
        }
      }
      return const [];
    }

    final updatedList = list.map((entry) {
      final isCurrent = (currentUserId != null &&
              currentUserId.isNotEmpty &&
              entry.userId == currentUserId) ||
          entry.isCurrentUser;

      if (isCurrent) {
        final streak = liveStreak > 0
            ? liveStreak
            : (entry.streakDays > 0 ? entry.streakDays : 1);
        final xp = liveXp > 0 ? math.max(liveXp, entry.weeklyXp) : entry.weeklyXp;
        final trackVal = liveTrack.isNotEmpty ? liveTrack : entry.track;

        return entry.copyWith(
          userName: liveDisplayName,
          avatarUrl: liveAvatarUrl ?? entry.avatarUrl,
          streakDays: streak,
          weeklyXp: xp,
          track: trackVal,
          isCurrentUser: true,
        );
      }

      if (entry.streakDays <= 0) {
        final derivedStreak = entry.weeklyXp >= 500
            ? 7
            : (entry.weeklyXp >= 200 ? 4 : (entry.weeklyXp >= 50 ? 2 : 1));
        return entry.copyWith(streakDays: derivedStreak);
      }
      return entry;
    }).toList();

    if (currentUserId != null && currentUserId.isNotEmpty) {
      final hasCurrentUser = updatedList.any(
        (e) => e.isCurrentUser || e.userId == currentUserId,
      );
      if (!hasCurrentUser) {
        final trackMatches = track == null ||
            track.isEmpty ||
            track == 'All' ||
            liveTrack.toLowerCase() == track.toLowerCase();

        if (trackMatches) {
          updatedList.add(
            LeaderboardEntryEntity(
              id: 'user_$currentUserId',
              userId: currentUserId,
              userName: liveDisplayName,
              avatarUrl: liveAvatarUrl,
              track: liveTrack,
              weeklyXp: liveXp,
              streakDays: liveStreak > 0 ? liveStreak : 1,
              isCurrentUser: true,
            ),
          );
        }
      }
    }

    // Sort all scholars by weeklyXp descending so everyone is in true rank order!
    updatedList.sort((a, b) => b.weeklyXp.compareTo(a.weeklyXp));

    // Re-index ranks and calculate league tiers dynamically
    for (var i = 0; i < updatedList.length; i++) {
      final item = updatedList[i];
      final calculatedTier = _calculateLeagueTier(item.weeklyXp);
      updatedList[i] = item.copyWith(
        rank: i + 1,
        leagueTier: calculatedTier,
      );
    }

    return updatedList;
  }

  String _calculateLeagueTier(int xp) {
    if (xp >= 1000) return "Dean's List";
    if (xp >= 600) return 'Diamond';
    if (xp >= 350) return 'Gold';
    if (xp >= 150) return 'Silver';
    return 'Bronze';
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> claimWeeklyXp({
    required int xpAmount,
  }) {
    return _remoteDataSource
        .claimWeeklyXp(xpAmount: xpAmount)
        .makeRequest();
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> syncUserProgress({
    int xpDelta = 0,
    int? streakDays,
    String? track,
  }) {
    return _remoteDataSource
        .syncUserProgress(
          xpDelta: xpDelta,
          streakDays: streakDays,
          track: track,
        )
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

  @override
  Future<Either<Failure, String>> getLiveKitToken({
    required String roomId,
    required String userId,
  }) {
    return _remoteDataSource
        .fetchLiveKitToken(roomId: roomId, userId: userId)
        .makeRequest();
  }

  @override
  Future<Either<Failure, bool>> toggleForumPostSubscription(String postId) {
    return _remoteDataSource.toggleForumPostSubscription(postId).makeRequest();
  }

  @override
  Future<Either<Failure, bool>> isForumPostSubscribed(String postId) {
    return _remoteDataSource.isForumPostSubscribed(postId).makeRequest();
  }

  @override
  Future<Either<Failure, bool>> toggleBookmarkForumPost(String postId) {
    return _remoteDataSource.toggleBookmarkForumPost(postId).makeRequest();
  }

  @override
  Future<Either<Failure, Set<String>>> getBookmarkedForumPostIds() {
    return _remoteDataSource.getBookmarkedForumPostIds().makeRequest();
  }

  @override
  Future<Either<Failure, Set<String>>> toggleFollowTopic(String topic) {
    return _remoteDataSource.toggleFollowTopic(topic).makeRequest();
  }

  @override
  Future<Either<Failure, Set<String>>> getFollowedTopics() {
    return _remoteDataSource.getFollowedTopics().makeRequest();
  }
}
