import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/client/community_api_client.dart';
import 'package:kortex/src/features/community/data/data_sources/community_local_data_source.dart';
import 'package:kortex/src/features/community/data/data_sources/community_remote_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/data/models/leaderboard_entry_model.dart';
import 'package:kortex/src/features/community/data/models/shared_deck_model.dart';
import 'package:kortex/src/features/community/data/models/study_circle_model.dart';
import 'package:kortex/src/features/community/data/models/study_community_model.dart';
import 'package:kortex/src/features/community/data/models/study_room_model.dart';

class CommunityRemoteDataSourceImpl implements CommunityRemoteDataSource {
  CommunityRemoteDataSourceImpl(
    this._client, {
    UserStorageService? userStorage,
    RealtimeClient? realtimeClient,
    CommunityLocalDataSource? localDataSource,
    LocalStorageService? localStorage,
  })  : _userStorage = userStorage,
        _realtime = realtimeClient ?? RealtimeClient.instance,
        _localDataSourceOverride = localDataSource,
        _localStorageOverride = localStorage;

  final CommunityApiClient _client;
  final UserStorageService? _userStorage;
  final RealtimeClient _realtime;
  final CommunityLocalDataSource? _localDataSourceOverride;
  final LocalStorageService? _localStorageOverride;

  CommunityLocalDataSource? get _localDataSource {
    if (_localDataSourceOverride != null) return _localDataSourceOverride;
    try {
      return locator<CommunityLocalDataSource>();
    } on Object catch (_) {
      return null;
    }
  }

  LocalStorageService? get _localStorage {
    if (_localStorageOverride != null) return _localStorageOverride;
    try {
      return locator<LocalStorageService>();
    } on Object catch (_) {
      return null;
    }
  }

  CrashlyticsService? get _crashlyticsService {
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

  // In-memory cache of replies per post, rebuilt from DB snapshots + WS events
  final Map<String, List<ForumReplyModel>> _replyCache = {};
  final Map<String, StreamController<List<ForumReplyModel>>> _replyControllers =
      {};

  @override
  Future<List<StudyRoomModel>> fetchStudyRooms({String? category}) async {
    try {
      final params = <String, dynamic>{
        'select': '*',
        'order': 'created_at.desc',
      };
      if (category != null && category.isNotEmpty && category != 'All') {
        params['category'] = 'eq.$category';
      }

      final res = await _client.fetchStudyRooms(params);
      final rawList = res.data is List ? (res.data as List) : <dynamic>[];
      final rooms = rawList
          .map((e) => StudyRoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (rooms.isNotEmpty) {
        _persistRoomsLocally(rooms);
      }
      return rooms;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.fetchStudyRooms failed',
          ),
        );
      }
      final cached = _getLocalPersistedRooms(category: category);
      if (cached.isNotEmpty) {
        return cached;
      }
      return _getCuratedFallbackRooms(category: category);
    }
  }

  @override
  Future<StudyRoomModel> createStudyRoom({
    required String title,
    required String subject,
    required String category,
    required int pomodoroMinutes,
    String ambientSoundTrack = 'lofi',
    String? activeGoal,
    bool isSilentFocus = true,
  }) async {
    final userId = _userStorage?.getUserId();
    final res = await _client.createStudyRoom(
      {
        'title': title,
        'subject': subject,
        'category': category,
        'pomodoro_duration_minutes': pomodoroMinutes,
        'pomodoro_state': 'focusing',
        'pomodoro_started_at': DateTime.now().toIso8601String(),
        'active_participants_count': 1,
        'ambient_sound_track': ambientSoundTrack,
        'active_goal': activeGoal,
        'is_silent_focus': isSilentFocus,
        'created_by': ?userId,
      },
    );
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to create study room');
    }
    final room = StudyRoomModel.fromJson(rawList.first as Map<String, dynamic>);
    final cached = _getLocalPersistedRooms();
    _persistRoomsLocally([room, ...cached.where((r) => r.id != room.id)]);
    return room;
  }

  @override
  Stream<StudyRoomModel> watchStudyRoom(String roomId) {
    // Subscribe to real-time DB changes for this specific room
    return _realtime
        .watchTable('study_rooms', filter: 'id=eq.$roomId')
        .where((e) => e.type != RealtimeEventType.delete)
        .map((e) => StudyRoomModel.fromJson(e.record));
  }

  @override
  Future<List<ForumPostModel>> fetchForumPosts({
    String? track,
    bool? questionsOnly,
  }) async {
    final params = <String, dynamic>{
      'select': '*,forum_replies(*)',
      'order': 'created_at.desc',
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }
    if (questionsOnly == true) {
      params['is_question'] = 'eq.true';
    }

    try {
      final res = await _client.fetchForumPosts(params);
      final rawList = res.data is List ? (res.data as List) : <dynamic>[];
      final posts = rawList
          .map((e) => ForumPostModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Write-through caching to SQLite
      if (_localDataSource != null && posts.isNotEmpty) {
        unawaited(_localDataSource!.saveForumPosts(posts));
      }

      // Populate in-memory reply cache
      for (final post in posts) {
        if (post.replies.isNotEmpty) {
          final cache = _replyCache.putIfAbsent(post.id, () => []);
          for (final reply in post.replies) {
            if (!cache.any((r) => r.id == reply.id)) {
              cache.add(reply);
            }
          }
        }
      }

      return posts;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason:
                'CommunityRemoteDataSource.fetchForumPosts failed, checking SQLite cache',
          ),
        );
      }

      // Read-through fallback to local SQLite cache
      if (_localDataSource != null) {
        try {
          final cachedPosts =
              await _localDataSource!.getForumPosts(track: track);
          if (cachedPosts.isNotEmpty) {
            return cachedPosts;
          }
        } on Object catch (_) {}
      }

      rethrow;
    }
  }

  @override
  Future<ForumPostModel> createForumPost({
    required String title,
    required String content,
    required String track,
    String? latexContent,
    bool isQuestion = false,
    String syllabusTag = 'General',
    bool isAnonymous = false,
  }) async {
    final userId = isAnonymous ? null : _userStorage?.getUserId();
    final authorName = isAnonymous
        ? 'Anonymous Scholar'
        : (_userStorage?.getUserDisplayName() ?? 'Scholar');
    final authorAvatar = isAnonymous ? null : _userStorage?.getUserAvatarUrl();

    final payload = <String, dynamic>{
      'title': title,
      'content': content,
      'track': track,
      'latex_content': latexContent,
      'is_question': isQuestion,
      'syllabus_tag': syllabusTag,
      'author_name': authorName,
      'author_id': ?userId,
      'author_avatar': ?authorAvatar,
    };

    final res = await _client.createForumPost(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to create forum post');
    }
    final post = ForumPostModel.fromJson(rawList.first as Map<String, dynamic>);
    unawaited(_localDataSource?.saveForumPost(post));
    return post;
  }

  @override
  Future<ForumReplyModel> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
  }) async {
    final userId = _userStorage?.getUserId();
    final authorName = _userStorage?.getUserDisplayName() ?? 'Scholar';
    final authorAvatar = _userStorage?.getUserAvatarUrl();

    final payload = <String, dynamic>{
      'post_id': postId,
      'content': content,
      'latex_content': latexContent,
      'author_name': authorName,
      'author_id': ?userId,
      'author_avatar': ?authorAvatar,
    };

    final res = await _client.replyToForumPost(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to add reply');
    }
    final reply =
        ForumReplyModel.fromJson(rawList.first as Map<String, dynamic>);
    final cache = _replyCache.putIfAbsent(postId, () => []);
    if (!cache.any((r) => r.id == reply.id)) {
      cache.add(reply);
    }
    unawaited(_localDataSource?.saveForumReply(reply));
    final controller = _replyControllers[postId];
    if (controller != null && !controller.isClosed) {
      controller.add(List.unmodifiable(cache));
    }
    return reply;
  }

  @override
  Future<bool> verifyForumReply({
    required String postId,
    required String replyId,
  }) async {
    try {
      await _client.verifyForumReply({
        'p_post_id': postId,
        'p_reply_id': replyId,
      });

      final cache = _replyCache[postId];
      if (cache != null) {
        for (var i = 0; i < cache.length; i++) {
          final isMatch = cache[i].id == replyId;
          final updated = ForumReplyModel(
            id: cache[i].id,
            postId: cache[i].postId,
            authorId: cache[i].authorId,
            authorName: cache[i].authorName,
            authorAvatar: cache[i].authorAvatar,
            content: cache[i].content,
            latexContent: cache[i].latexContent,
            isVerifiedSolution: isMatch,
            upvotes: cache[i].upvotes,
            createdAt: cache[i].createdAt,
          );
          cache[i] = updated;
          if (isMatch) {
            unawaited(_localDataSource?.saveForumReply(updated));
          }
        }
        final controller = _replyControllers[postId];
        if (controller != null && !controller.isClosed) {
          controller.add(List.unmodifiable(cache));
        }
      }
      return true;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.verifyForumReply failed',
          ),
        );
      }
      return false;
    }
  }

  @override
  Stream<List<ForumReplyModel>> watchForumReplies(String postId) {
    final streamController = _replyControllers.putIfAbsent(
      postId,
      StreamController<List<ForumReplyModel>>.broadcast,
    );

    // If cache already has items, emit immediately
    if (_replyCache.containsKey(postId) && _replyCache[postId]!.isNotEmpty) {
      scheduleMicrotask(() {
        if (!streamController.isClosed) {
          streamController.add(List.unmodifiable(_replyCache[postId]!));
        }
      });
    } else if (_localDataSource != null) {
      // Seed from SQLite cache
      _localDataSource!.getRepliesForPost(postId).then((cachedReplies) {
        if (cachedReplies.isNotEmpty) {
          final currentCache = _replyCache.putIfAbsent(postId, () => []);
          for (final r in cachedReplies) {
            if (!currentCache.any((c) => c.id == r.id)) {
              currentCache.add(r);
            }
          }
          if (!streamController.isClosed) {
            streamController.add(List.unmodifiable(currentCache));
          }
        }
      }).ignore();
    }

    // Seed or refresh cache via REST
    _client
        .fetchForumPosts({
          'select': 'forum_replies(*)',
          'id': 'eq.$postId',
          'limit': '1',
        })
        .then((res) {
          try {
            final rawList = res.data is List ? (res.data as List) : <dynamic>[];
            if (rawList.isNotEmpty) {
              final postJson = rawList.first as Map<String, dynamic>;
              final repliesRaw =
                  postJson['forum_replies'] as List<dynamic>? ?? [];
              final fetchedReplies = repliesRaw
                  .map((r) =>
                      ForumReplyModel.fromJson(r as Map<String, dynamic>))
                  .toList();
              final currentCache = _replyCache.putIfAbsent(postId, () => []);
              for (final fetched in fetchedReplies) {
                if (!currentCache.any((r) => r.id == fetched.id)) {
                  currentCache.add(fetched);
                  unawaited(_localDataSource?.saveForumReply(fetched));
                }
              }
              if (!streamController.isClosed) {
                streamController.add(List.unmodifiable(currentCache));
              }
            }
          } on Exception catch (_) {}
        })
        .ignore();

    // Listen for new inserts via WebSocket
    final wsSub = _realtime
        .watchTable('forum_replies', filter: 'post_id=eq.$postId')
        .listen((event) {
          if (event.type == RealtimeEventType.insert) {
            try {
              final reply = ForumReplyModel.fromJson(event.record);
              final cache = _replyCache.putIfAbsent(postId, () => []);
              if (!cache.any((r) => r.id == reply.id)) {
                cache.add(reply);
                unawaited(_localDataSource?.saveForumReply(reply));
              }
              if (!streamController.isClosed) {
                streamController.add(List.unmodifiable(cache));
              }
            } on Exception catch (_) {}
          }
        });

    streamController.onCancel = () => wsSub.cancel().ignore();

    return streamController.stream;
  }

  @override
  Future<List<StudyCircleModel>> fetchStudyCircles({String? track}) async {
    final params = <String, dynamic>{
      'select': '*,study_circle_members(*)',
      'order': 'created_at.desc',
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }

    try {
      final res = await _client.fetchStudyCircles(params);
      final rawList = res.data is List ? (res.data as List) : <dynamic>[];
      final circles = rawList
          .map((e) => StudyCircleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (circles.isNotEmpty) {
        _persistCirclesLocally(circles);
      }
      return circles;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.fetchStudyCircles failed',
          ),
        );
      }
      final cached = _getLocalPersistedCircles(track: track);
      if (cached.isNotEmpty) {
        return cached;
      }
      return _getCuratedFallbackCircles(track: track);
    }
  }

  @override
  Future<StudyCircleModel> createStudyCircle({
    required String name,
    required String track,
    int targetWeeklyMinutes = 600,
  }) async {
    final userId = _userStorage?.getUserId();
    final userName = _userStorage?.getUserDisplayName() ?? 'Scholar';
    final avatarUrl = _userStorage?.getUserAvatarUrl();

    final payload = <String, dynamic>{
      'name': name,
      'track': track,
      'target_weekly_minutes': targetWeeklyMinutes,
      'creator_id': ?userId,
      'max_members': 6,
      'member_count': 1,
    };
    final res = await _client.createStudyCircle(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to create study circle');
    }
    final createdCircle =
        StudyCircleModel.fromJson(rawList.first as Map<String, dynamic>);
    final cachedCircles = _getLocalPersistedCircles();
    _persistCirclesLocally([
      createdCircle,
      ...cachedCircles.where((c) => c.id != createdCircle.id),
    ]);

    if (userId != null) {
      try {
        await _client.joinStudyCircle({
          'circle_id': createdCircle.id,
          'user_id': userId,
          'user_name': userName,
          'avatar_url': ?avatarUrl,
          'role': 'creator',
        });
      } on Object catch (_) {}
    }

    return createdCircle;
  }

  @override
  Future<StudyCircleModel> joinStudyCircle(String circleId) async {
    final userId = _userStorage?.getUserId();
    final userName = _userStorage?.getUserDisplayName() ?? 'Scholar';
    final avatarUrl = _userStorage?.getUserAvatarUrl();

    if (userId != null) {
      await _client.joinStudyCircle({
        'circle_id': circleId,
        'user_id': userId,
        'user_name': userName,
        'avatar_url': ?avatarUrl,
        'role': 'member',
      });
    }

    final res = await _client.fetchStudyCircles({
      'select': '*,study_circle_members(*)',
      'id': 'eq.$circleId',
      'limit': '1',
    });
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isNotEmpty) {
      final joined =
          StudyCircleModel.fromJson(rawList.first as Map<String, dynamic>);
      final cachedCircles = _getLocalPersistedCircles();
      _persistCirclesLocally([
        joined,
        ...cachedCircles.where((c) => c.id != joined.id),
      ]);
      return joined;
    }
    throw Exception('Failed to fetch joined study circle');
  }

  @override
  Future<List<SharedDeckModel>> fetchSharedDecks({String? subject}) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'downloads_count.desc',
    };
    if (subject != null && subject.isNotEmpty && subject != 'All') {
      params['subject'] = 'eq.$subject';
    }

    try {
      final res = await _client.fetchSharedDecks(params);
      final rawList = res.data is List ? (res.data as List) : <dynamic>[];
      final decks = rawList
          .map((e) => SharedDeckModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (decks.isNotEmpty) {
        _persistSharedDecksLocally(decks);
      }
      return decks;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.fetchSharedDecks failed',
          ),
        );
      }
      final cached = _getLocalPersistedSharedDecks(subject: subject);
      if (cached.isNotEmpty) {
        return cached;
      }
      return _getCuratedFallbackSharedDecks(subject: subject);
    }
  }

  @override
  Future<SharedDeckModel> publishDeck({
    required String title,
    required String subject,
    required String description,
    required String category,
    required int totalCards,
    required List<Map<String, dynamic>> cardsJson,
    String syllabusTag = 'General',
  }) async {
    final userId = _userStorage?.getUserId();
    final ownerName = _userStorage?.getUserDisplayName() ?? 'Scholar';

    final payload = <String, dynamic>{
      'title': title,
      'subject': subject,
      'syllabus_tag': syllabusTag,
      'description': description,
      'category': category,
      'total_cards': totalCards,
      'cards': cardsJson,
      'owner_name': ownerName,
      'owner_id': ?userId,
    };

    final res = await _client.publishDeck(payload);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to publish shared deck');
    }
    final published =
        SharedDeckModel.fromJson(rawList.first as Map<String, dynamic>);
    final cachedDecks = _getLocalPersistedSharedDecks();
    _persistSharedDecksLocally([
      published,
      ...cachedDecks.where((d) => d.id != published.id),
    ]);
    return published;
  }

  @override
  Future<Map<String, dynamic>> cloneSharedDeck(String sharedDeckId) async {
    final res = await _client.cloneSharedDeck(
      {'p_shared_deck_id': sharedDeckId},
    );
    if (res.data is Map<String, dynamic>) {
      return res.data as Map<String, dynamic>;
    }
    return {};
  }

  @override
  Stream<List<LeaderboardEntryModel>> streamLeaderboards({String? track}) {
    // Accumulate leaderboard snapshot, then push updates for any change via WebSocket
    final streamController =
        StreamController<List<LeaderboardEntryModel>>.broadcast();
    final cache = <String, LeaderboardEntryModel>{};

    // Initial fetch to seed the cache
    fetchLeaderboards(track: track)
        .then((entries) {
          for (final e in entries) {
            cache[e.userId] = e;
          }
          if (!streamController.isClosed) {
            streamController.add(_sortedLeaderboard(cache));
          }
        })
        .ignore();

    // Stream any row changes in the leaderboards table
    final wsSub = _realtime.watchTable('leaderboards').listen((event) {
      try {
        if (event.type == RealtimeEventType.delete) {
          final id = event.oldRecord?['user_id'] as String?;
          if (id != null) cache.remove(id);
        } else {
          final entry = LeaderboardEntryModel.fromJson(event.record);
          // Only include if track filter matches
          if (track == null ||
              track.isEmpty ||
              track == 'All' ||
              (event.record['track'] as String? ?? '') == track) {
            cache[entry.userId] = entry;
          }
        }
        if (!streamController.isClosed) {
          streamController.add(_sortedLeaderboard(cache));
        }
      } on Exception catch (_) {}
    });

    streamController.onCancel = () => wsSub.cancel().ignore();
    return streamController.stream;
  }

  List<LeaderboardEntryModel> _sortedLeaderboard(
    Map<String, LeaderboardEntryModel> cache,
  ) {
    final list = cache.values.toList()
      ..sort((a, b) => (b.weeklyXp).compareTo(a.weeklyXp));
    return list;
  }

  @override
  Future<List<LeaderboardEntryModel>> fetchLeaderboards({String? track}) async {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'weekly_xp.desc',
      'limit': '50',
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }

    final res = await _client.fetchLeaderboards(params);
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    return rawList
        .map((e) => LeaderboardEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<StudyCommunityModel> autoProvisionCommunity({
    required String courseCode,
    required String title,
    String? department,
  }) async {
    final res = await _client.autoProvisionCommunity(
      {
        'p_course_code': courseCode,
        'p_title': title,
        'p_department': department ?? 'General',
      },
    );
    if (res.data is Map<String, dynamic>) {
      return StudyCommunityModel.fromJson(res.data as Map<String, dynamic>);
    }
    throw Exception('Failed to auto-provision community');
  }

  @override
  Future<StudyCommunityModel> fetchCourseCommunityStats(
    String courseCode,
  ) async {
    final normalized = courseCode.trim().toUpperCase();
    final res = await _client.fetchCourseCommunityStats(
      {
        'course_code': 'eq.$normalized',
        'select': '*',
        'limit': '1',
      },
    );
    final rawList = res.data is List ? (res.data as List) : <dynamic>[];
    if (rawList.isNotEmpty) {
      return StudyCommunityModel.fromJson(
        rawList.first as Map<String, dynamic>,
      );
    }
    return autoProvisionCommunity(
      courseCode: normalized,
      title: '$normalized Study Hub',
    );
  }

  @override
  Future<String> fetchLiveKitToken({
    required String roomId,
    required String userId,
  }) async {
    final res = await _client.generateLiveKitToken({
      'room_id': roomId,
      'user_id': userId,
    });
    final dynamic data = res.data;
    if (data is Map<String, dynamic> && data['token'] != null) {
      return data['token'].toString();
    }
    throw const ServerException(message: 'Failed to mint LiveKit audio token');
  }

  void _persistRoomsLocally(List<StudyRoomModel> rooms) {
    try {
      final storage = _localStorage;
      if (storage == null) return;
      final encoded = jsonEncode(rooms.map((r) => r.toJson()).toList());
      unawaited(
        storage.savePreference(
          key: PrefKeys.persistedStudyRooms,
          data: encoded,
        ),
      );
    } on Object catch (_) {}
  }

  List<StudyRoomModel> _getLocalPersistedRooms({String? category}) {
    try {
      final storage = _localStorage;
      if (storage == null) return [];
      final raw = storage.getPreference(key: PrefKeys.persistedStudyRooms);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List<dynamic>?) ?? [];
      final rooms = list
          .map((e) => StudyRoomModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (category != null && category.isNotEmpty && category != 'All') {
        return rooms
            .where((r) => r.category.toLowerCase() == category.toLowerCase())
            .toList();
      }
      return rooms;
    } on Object catch (_) {
      return [];
    }
  }

  List<StudyRoomModel> _getCuratedFallbackRooms({String? category}) {
    const allFallback = [
      StudyRoomModel(
        id: 'curated_room_pomodoro_silent',
        title: 'Silent Pomodoro Library',
        subject: 'General Study',
        activeParticipantsCount: 14,
        activeGoal: 'Deep study & silent focus sprint',
      ),
      StudyRoomModel(
        id: 'curated_room_stem_lab',
        title: 'Deep Work STEM Lab',
        subject: 'Science & Engineering',
        category: 'STEM',
        pomodoroDurationMinutes: 50,
        activeParticipantsCount: 8,
        ambientSoundTrack: 'binaural',
        activeGoal: 'Problem solving & derivation sprint',
      ),
      StudyRoomModel(
        id: 'curated_room_exam_prep',
        title: 'Exam Sprint Pod',
        subject: 'All Subjects',
        category: 'Exam Prep',
        pomodoroDurationMinutes: 45,
        activeParticipantsCount: 19,
        ambientSoundTrack: 'rain',
        activeGoal: 'Past question drills & active recall',
      ),
    ];
    if (category != null && category.isNotEmpty && category != 'All') {
      final filtered = allFallback
          .where((r) => r.category.toLowerCase() == category.toLowerCase())
          .toList();
      if (filtered.isNotEmpty) return filtered;
    }
    return allFallback;
  }

  void _persistCirclesLocally(List<StudyCircleModel> circles) {
    try {
      final storage = _localStorage;
      if (storage == null) return;
      final encoded = jsonEncode(circles.map((c) => c.toJson()).toList());
      unawaited(
        storage.savePreference(
          key: PrefKeys.persistedStudyCircles,
          data: encoded,
        ),
      );
    } on Object catch (_) {}
  }

  List<StudyCircleModel> _getLocalPersistedCircles({String? track}) {
    try {
      final storage = _localStorage;
      if (storage == null) return [];
      final raw = storage.getPreference(key: PrefKeys.persistedStudyCircles);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List<dynamic>?) ?? [];
      final circles = list
          .map((e) => StudyCircleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (track != null && track.isNotEmpty && track != 'All') {
        return circles
            .where((c) => c.track.toLowerCase() == track.toLowerCase())
            .toList();
      }
      return circles;
    } on Object catch (_) {
      return [];
    }
  }

  List<StudyCircleModel> _getCuratedFallbackCircles({String? track}) {
    final effectiveTrack =
        (track != null && track.isNotEmpty && track != 'All')
            ? track
            : 'General';
    return [
      StudyCircleModel(
        id: 'curated_circle_sprint',
        name: '$effectiveTrack Study Circle',
        track: effectiveTrack,
        memberCount: 5,
      ),
    ];
  }

  void _persistSharedDecksLocally(List<SharedDeckModel> decks) {
    try {
      final storage = _localStorage;
      if (storage == null) return;
      final encoded = jsonEncode(decks.map((d) => d.toJson()).toList());
      unawaited(
        storage.savePreference(
          key: PrefKeys.persistedSharedDecks,
          data: encoded,
        ),
      );
    } on Object catch (_) {}
  }

  List<SharedDeckModel> _getLocalPersistedSharedDecks({String? subject}) {
    try {
      final storage = _localStorage;
      if (storage == null) return [];
      final raw = storage.getPreference(key: PrefKeys.persistedSharedDecks);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List<dynamic>?) ?? [];
      final decks = list
          .map((e) => SharedDeckModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (subject != null && subject.isNotEmpty && subject != 'All') {
        return decks
            .where((d) => d.subject.toLowerCase() == subject.toLowerCase())
            .toList();
      }
      return decks;
    } on Object catch (_) {
      return [];
    }
  }

  List<SharedDeckModel> _getCuratedFallbackSharedDecks({String? subject}) {
    final effectiveSubject =
        (subject != null && subject.isNotEmpty && subject != 'All')
            ? subject
            : 'General Studies';
    return [
      SharedDeckModel(
        id: 'curated_deck_high_yield',
        ownerId: 'kortex_team',
        ownerName: 'Kortex Academic Curators',
        title: '$effectiveSubject Core Exam Formulas & Review',
        subject: effectiveSubject,
        syllabusTag: 'Universal',
        description:
            'High-yield flashcards covering key definitions, exam principles, and quick recall prompts.',
        category: 'Exam Prep',
        totalCards: 20,
        downloadsCount: 142,
        rating: 4.9,
      ),
    ];
  }
}
