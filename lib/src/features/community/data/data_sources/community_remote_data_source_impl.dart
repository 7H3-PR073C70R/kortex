import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/networking/realtime/realtime_client.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
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
import 'package:retrofit/retrofit.dart';

class CommunityRemoteDataSourceImpl implements CommunityRemoteDataSource {
  CommunityRemoteDataSourceImpl(
    this._client, {
    UserStorageService? userStorage,
    RealtimeClient? realtimeClient,
    CommunityLocalDataSource? localDataSource,
    LocalStorageService? localStorage,
  }) : _userStorage = userStorage,
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
          .where((r) => !_isAutoProvisionedHashRoom(r))
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
    String? sortFilter,
    String? searchQuery,
    int limit = 15,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'select': '*',
      'limit': limit,
      'offset': offset,
    };
    if (track != null && track.isNotEmpty && track != 'All') {
      params['track'] = 'eq.$track';
    }
    if (questionsOnly == true) {
      params['is_question'] = 'eq.true';
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      params['or'] = '(title.ilike.*$q*,content.ilike.*$q*,syllabus_tag.ilike.*$q*)';
    }

    var orderParam = 'created_at.desc';
    if (sortFilter != null) {
      switch (sortFilter) {
        case 'trending':
          orderParam = 'upvotes.desc,replies_count.desc,created_at.desc';
        case 'latest':
          orderParam = 'created_at.desc';
        case 'topToday':
        case 'top_today':
          orderParam = 'upvotes.desc,created_at.desc';
        case 'questions':
          params['is_question'] = 'eq.true';
          orderParam = 'created_at.desc';
        case 'solved':
          params['is_verified_solution'] = 'eq.true';
          orderParam = 'created_at.desc';
        case 'myPosts':
        case 'my_posts':
          final myId = _userStorage?.getUserId();
          if (myId != null && myId.isNotEmpty) {
            params['author_id'] = 'eq.$myId';
          } else {
            final myName = _userStorage?.getUserDisplayName();
            if (myName != null && myName.isNotEmpty) {
              params['author_name'] = 'eq.$myName';
            }
          }
          orderParam = 'created_at.desc';
        case 'saved':
        case 'bookmarks':
          final bookmarked = await getBookmarkedForumPostIds();
          if (bookmarked.isEmpty) {
            return [];
          }
          params['id'] = 'in.(${bookmarked.join(",")})';
          orderParam = 'created_at.desc';
      }
    }
    params['order'] = orderParam;

    try {
      final res = await _client.fetchForumPosts(params);
      final rawList = res.data is List ? (res.data as List) : <dynamic>[];
      final posts = rawList
          .map((e) => ForumPostModel.fromJson(e as Map<String, dynamic>))
          .toList();

      if (sortFilter == 'saved' || sortFilter == 'bookmarks') {
        if (_localDataSource != null) {
          try {
            final bookmarked = await getBookmarkedForumPostIds();
            final cached = await _localDataSource!.getForumPosts(track: track);
            for (final cp in cached.where((p) => bookmarked.contains(p.id))) {
              if (!posts.any((p) => p.id == cp.id)) {
                posts.add(cp);
              }
            }
          } on Object catch (_) {}
        }
      }

      // Write-through caching to SQLite
      if (_localDataSource != null && posts.isNotEmpty) {
        unawaited(_localDataSource!.saveForumPosts(posts));
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
          var cachedPosts = await _localDataSource!.getForumPosts(
            track: track,
          );
          if (sortFilter == 'myPosts' || sortFilter == 'my_posts') {
            final myId = _userStorage?.getUserId();
            final myName = _userStorage?.getUserDisplayName();
            cachedPosts = cachedPosts.where((p) => (myId != null && p.authorId == myId) || (myName != null && p.authorName == myName)).toList();
          } else if (sortFilter == 'saved' || sortFilter == 'bookmarks') {
            final bookmarked = await getBookmarkedForumPostIds();
            cachedPosts = cachedPosts.where((p) => bookmarked.contains(p.id)).toList();
          }
          if (cachedPosts.isNotEmpty) {
            if (searchQuery != null && searchQuery.trim().isNotEmpty) {
              final q = searchQuery.trim().toLowerCase();
              return cachedPosts.where((p) {
                return p.title.toLowerCase().contains(q) ||
                    p.content.toLowerCase().contains(q) ||
                    p.syllabusTag.toLowerCase().contains(q) ||
                    p.tags.any((t) => t.toLowerCase().contains(q));
              }).toList();
            }
            return cachedPosts;
          }
        } on Object catch (_) {}
      }

      rethrow;
    }
  }

  @override
  Future<List<ForumReplyModel>> fetchForumReplies({
    required String postId,
    String? parentReplyId,
    bool topLevelOnly = false,
    String? sortFilter,
    int limit = 15,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'select': '*',
      'post_id': 'eq.$postId',
      'limit': limit,
      'offset': offset,
      'order': 'upvotes.desc,created_at.asc',
    };
    if (topLevelOnly) {
      params['parent_reply_id'] = 'is.null';
    } else if (parentReplyId != null && parentReplyId.isNotEmpty) {
      params['parent_reply_id'] = 'eq.$parentReplyId';
      params['order'] = 'created_at.asc';
    }

    try {
      final res = await _client.fetchForumReplies(params);
      final rawList = res.data is List ? (res.data as List) : <dynamic>[];
      final replies = rawList
          .map((e) => ForumReplyModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Write-through to SQLite and in-memory cache
      if (replies.isNotEmpty) {
        final cache = _replyCache.putIfAbsent(postId, () => []);
        for (final reply in replies) {
          if (!cache.any((r) => r.id == reply.id)) {
            cache.add(reply);
          }
          if (_localDataSource != null) {
            unawaited(_localDataSource!.saveForumReply(reply));
          }
        }
      }

      return replies;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason:
                'CommunityRemoteDataSource.fetchForumReplies failed, checking SQLite cache',
          ),
        );
      }

      if (_localDataSource != null) {
        try {
          final cached = await _localDataSource!.getRepliesForPost(postId);
          if (cached.isNotEmpty) {
            if (topLevelOnly) {
              return cached
                  .where((r) => r.parentReplyId == null || r.parentReplyId!.isEmpty)
                  .toList();
            } else if (parentReplyId != null && parentReplyId.isNotEmpty) {
              return cached
                  .where((r) => r.parentReplyId == parentReplyId)
                  .toList();
            }
            return cached;
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
    List<String>? tags,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    bool isAnonymous = false,
  }) async {
    // Duplicate check: verify if an identical question/discussion was already created (local cache + remote)
    try {
      if (_localDataSource != null) {
        final cached = await _localDataSource!.getForumPosts(track: track);
        if (cached.any((p) => p.title.trim().toLowerCase() == title.trim().toLowerCase())) {
          throw Exception('A discussion thread with this title already exists in $track.');
        }
      }

      final existingRes = await _client.fetchForumPosts({
        'select': 'id,title',
        'track': 'eq.$track',
        'title': 'ilike.${title.trim()}',
        'limit': 1,
      });
      final existingData = existingRes.data is List ? (existingRes.data as List) : <dynamic>[];
      if (existingData.isNotEmpty) {
        throw Exception('A discussion thread with this title already exists in $track.');
      }
    } on Exception catch (e) {
      if (e.toString().contains('already exists')) {
        rethrow;
      }
    }

    final rawUserId = isAnonymous ? null : _userStorage?.getUserId();
    final userId = (rawUserId != null && rawUserId.trim().isNotEmpty)
        ? rawUserId.trim()
        : null;
    final authorName = isAnonymous
        ? 'Anonymous Scholar'
        : (_userStorage?.getUserDisplayName() ?? 'Scholar');
    final authorAvatar = isAnonymous ? null : _userStorage?.getUserAvatarUrl();

    var enrichedContent = content.trim();
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      enrichedContent += '\n<!-- media: ${jsonEncode(mediaUrls)} -->';
    }
    if (voiceNoteUrl != null && voiceNoteUrl.trim().isNotEmpty) {
      final durPart = voiceNoteDurationSeconds != null ? ' duration:$voiceNoteDurationSeconds' : '';
      enrichedContent += '\n<!-- voice: ${voiceNoteUrl.trim()}$durPart -->';
    }
    if (tags != null && tags.isNotEmpty) {
      enrichedContent += '\n<!-- tags: ${jsonEncode(tags)} -->';
    }

    final payload = <String, dynamic>{
      'title': title.trim(),
      'content': enrichedContent,
      'track': track,
      if (latexContent != null && latexContent.trim().isNotEmpty)
        'latex_content': latexContent.trim(),
      'is_question': isQuestion,
      'syllabus_tag': syllabusTag,
      if (tags != null && tags.isNotEmpty)
        'tags': tags,
      if (mediaUrls != null && mediaUrls.isNotEmpty)
        'media_urls': mediaUrls,
      if (voiceNoteUrl != null && voiceNoteUrl.trim().isNotEmpty)
        'voice_note_url': voiceNoteUrl.trim(),
      'voice_note_duration_seconds': ?voiceNoteDurationSeconds,
      'author_name': authorName,
      'author_id': ?userId,
      if (authorAvatar != null && authorAvatar.trim().isNotEmpty)
        'author_avatar': authorAvatar,
    };

    final res = await _safeCreateForumPost(payload);
    final dynamic responseData = res.data;
    final rawList = responseData is List ? responseData : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to create forum post');
    }
    var post = ForumPostModel.fromJson(rawList.first as Map<String, dynamic>);
    if (post.mediaUrls.isEmpty && mediaUrls != null && mediaUrls.isNotEmpty) {
      post = post.copyWith(mediaUrls: mediaUrls);
    }
    if (post.tags.isEmpty && tags != null && tags.isNotEmpty) {
      post = post.copyWith(tags: tags);
    }
    if (post.voiceNoteUrl == null && voiceNoteUrl != null && voiceNoteUrl.isNotEmpty) {
      post = post.copyWith(
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDurationSeconds: voiceNoteDurationSeconds,
      );
    }
    unawaited(_localDataSource?.saveForumPost(post));
    return post;
  }

  String _extractPostgrestErrorString(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      return '${e.message} $data $e';
    }
    return e.toString();
  }

  Future<HttpResponse<dynamic>> _safeCreateForumPost(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _client.createForumPost(payload);
    } catch (e) {
      final errStr = _extractPostgrestErrorString(e);
      if (errStr.contains('PGRST204') || errStr.contains('Could not find the') || errStr.contains('schema cache')) {
        final match = RegExp("Could not find the '([^']+)' column").firstMatch(errStr);
        final missingCol = match?.group(1);
        final fallback = Map<String, dynamic>.from(payload);
        if (missingCol != null && fallback.containsKey(missingCol)) {
          fallback.remove(missingCol);
          return _safeCreateForumPost(fallback);
        } else {
          fallback
            ..remove('media_urls')
            ..remove('voice_note_url')
            ..remove('voice_note_duration_seconds')
            ..remove('tags')
            ..remove('is_anonymous');
          return _safeCreateForumPost(fallback);
        }
      }
      rethrow;
    }
  }

  @override
  Future<bool> deleteForumPost(String postId) async {
    try {
      await _client.deleteForumPost({'id': 'eq.$postId'});
      _replyCache.remove(postId);
      if (_localDataSource != null) {
        unawaited(_localDataSource!.deleteForumPost(postId));
      }
      return true;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.deleteForumPost failed',
          ),
        );
      }
      // Fallback local deletion
      _replyCache.remove(postId);
      if (_localDataSource != null) {
        unawaited(_localDataSource!.deleteForumPost(postId));
      }
      return true;
    }
  }

  @override
  Future<ForumReplyModel> replyToForumPost({
    required String postId,
    required String content,
    String? latexContent,
    String? parentReplyId,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
  }) async {
    final rawUserId = _userStorage?.getUserId();
    final userId = (rawUserId != null && rawUserId.trim().isNotEmpty)
        ? rawUserId.trim()
        : null;
    final authorName = _userStorage?.getUserDisplayName() ?? 'Scholar';
    final authorAvatar = _userStorage?.getUserAvatarUrl();

    var enrichedContent = content.trim();
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      enrichedContent += '\n<!-- media: ${jsonEncode(mediaUrls)} -->';
    }
    if (voiceNoteUrl != null && voiceNoteUrl.trim().isNotEmpty) {
      final durPart = voiceNoteDurationSeconds != null ? ' duration:$voiceNoteDurationSeconds' : '';
      enrichedContent += '\n<!-- voice: ${voiceNoteUrl.trim()}$durPart -->';
    }

    final payload = <String, dynamic>{
      'post_id': postId,
      'content': enrichedContent,
      if (latexContent != null && latexContent.trim().isNotEmpty)
        'latex_content': latexContent,
      if (parentReplyId != null && parentReplyId.trim().isNotEmpty)
        'parent_reply_id': parentReplyId,
      if (mediaUrls != null && mediaUrls.isNotEmpty)
        'media_urls': mediaUrls,
      if (voiceNoteUrl != null && voiceNoteUrl.trim().isNotEmpty)
        'voice_note_url': voiceNoteUrl.trim(),
      'voice_note_duration_seconds': ?voiceNoteDurationSeconds,
      'author_name': authorName,
      'author_id': ?userId,
      if (authorAvatar != null && authorAvatar.trim().isNotEmpty)
        'author_avatar': authorAvatar,
    };

    final res = await _safeReplyToForumPost(payload);
    final dynamic responseData = res.data;
    final rawList = responseData is List ? responseData : <dynamic>[];
    if (rawList.isEmpty) {
      throw Exception('Failed to add reply');
    }
    var reply = ForumReplyModel.fromJson(
      rawList.first as Map<String, dynamic>,
    );
    if (reply.mediaUrls.isEmpty && mediaUrls != null && mediaUrls.isNotEmpty) {
      reply = reply.copyWith(mediaUrls: mediaUrls);
    }
    if (reply.voiceNoteUrl == null && voiceNoteUrl != null && voiceNoteUrl.isNotEmpty) {
      reply = reply.copyWith(
        voiceNoteUrl: voiceNoteUrl,
        voiceNoteDurationSeconds: voiceNoteDurationSeconds,
      );
    }
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

  Future<HttpResponse<dynamic>> _safeReplyToForumPost(
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _client.replyToForumPost(payload);
    } catch (e) {
      final errStr = _extractPostgrestErrorString(e);
      if (errStr.contains('PGRST204') || errStr.contains('Could not find the') || errStr.contains('schema cache')) {
        final match = RegExp("Could not find the '([^']+)' column").firstMatch(errStr);
        final missingCol = match?.group(1);
        final fallback = Map<String, dynamic>.from(payload);
        if (missingCol != null && fallback.containsKey(missingCol)) {
          fallback.remove(missingCol);
          return _safeReplyToForumPost(fallback);
        } else {
          fallback
            ..remove('media_urls')
            ..remove('voice_note_url')
            ..remove('voice_note_duration_seconds')
            ..remove('is_anonymous');
          return _safeReplyToForumPost(fallback);
        }
      }
      rethrow;
    }
  }

  @override
  Future<bool> voteForumPost({
    required String postId,
    required int voteDirection,
  }) async {
    try {
      final currentPost = await _localDataSource?.getForumPost(postId);
      if (currentPost != null) {
        final prevVote = currentPost.userVote;
        final newVote = (prevVote == voteDirection) ? 0 : voteDirection;
        var newUpvotes = currentPost.upvotes;
        var newDownvotes = currentPost.downvotes;

        if (prevVote == 1) newUpvotes -= 1;
        if (prevVote == -1) newDownvotes -= 1;
        if (newVote == 1) newUpvotes += 1;
        if (newVote == -1) newDownvotes += 1;

        if (newUpvotes < 0) newUpvotes = 0;
        if (newDownvotes < 0) newDownvotes = 0;

        final updated = currentPost.copyWith(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          userVote: newVote,
        );
        await _localDataSource?.saveForumPost(updated);

        try {
          await _client.updateForumPost(
            {'id': 'eq.$postId'},
            {
              'upvotes': newUpvotes,
              'downvotes': newDownvotes,
            },
          );
        } on Object catch (_) {
          // Ignore network errors to preserve optimistic offline-first update
        }
      }
      return true;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.voteForumPost failed',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<bool> voteForumReply({
    required String postId,
    required String replyId,
    required int voteDirection,
  }) async {
    try {
      final cache = _replyCache[postId] ?? await _localDataSource?.getRepliesForPost(postId) ?? [];
      final replyIndex = cache.indexWhere((r) => r.id == replyId);
      if (replyIndex != -1) {
        final currentReply = cache[replyIndex];
        final prevVote = currentReply.userVote;
        final newVote = (prevVote == voteDirection) ? 0 : voteDirection;
        var newUpvotes = currentReply.upvotes;
        var newDownvotes = currentReply.downvotes;

        if (prevVote == 1) newUpvotes -= 1;
        if (prevVote == -1) newDownvotes -= 1;
        if (newVote == 1) newUpvotes += 1;
        if (newVote == -1) newDownvotes += 1;

        if (newUpvotes < 0) newUpvotes = 0;
        if (newDownvotes < 0) newDownvotes = 0;

        final updated = currentReply.copyWith(
          upvotes: newUpvotes,
          downvotes: newDownvotes,
          userVote: newVote,
        );

        cache[replyIndex] = updated;
        _replyCache[postId] = cache;
        await _localDataSource?.saveForumReply(updated);

        final controller = _replyControllers[postId];
        if (controller != null && !controller.isClosed) {
          controller.add(List.unmodifiable(cache));
        }

        try {
          await _client.updateForumReply(
            {'id': 'eq.$replyId'},
            {
              'upvotes': newUpvotes,
              'downvotes': newDownvotes,
            },
          );
        } on Object catch (_) {
          // Ignore network errors to preserve optimistic offline-first update
        }
      }
      return true;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.voteForumReply failed',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<bool> verifyForumReply({
    required String postId,
    required String replyId,
  }) async {
    try {
      try {
        await _client.verifyForumReply({
          'p_post_id': postId,
          'p_reply_id': replyId,
        });
      } on Object catch (_) {
        // Fallback to direct REST PATCH if the remote RPC stored procedure encounters schema mismatch (e.g. legacy forum_topics relation)
        try {
          await _client.updateForumReply(
            {'post_id': 'eq.$postId'},
            {'is_verified_solution': false},
          );
          await _client.updateForumReply(
            {'id': 'eq.$replyId'},
            {'is_verified_solution': true},
          );
          await _client.updateForumPost(
            {'id': 'eq.$postId'},
            {'is_verified_solution': true},
          );
        } on Object catch (_) {
          // Ignore REST errors to allow local-first optimistic cache update
        }
      }

      final cache = _replyCache[postId];
      if (cache != null) {
        for (var i = 0; i < cache.length; i++) {
          final isMatch = cache[i].id == replyId;
          final updated = cache[i].copyWith(
            isVerifiedSolution: isMatch,
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

    // Seed or refresh cache via direct REST call to /rest/v1/forum_replies
    _client
        .fetchForumReplies({
          'select': '*',
          'post_id': 'eq.$postId',
          'order': 'created_at.asc',
        })
        .then((res) {
          try {
            final rawList = res.data is List ? (res.data as List) : <dynamic>[];
            if (rawList.isNotEmpty) {
              final fetchedReplies = rawList
                  .map(
                    (r) => ForumReplyModel.fromJson(r as Map<String, dynamic>),
                  )
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
    final createdCircle = StudyCircleModel.fromJson(
      rawList.first as Map<String, dynamic>,
    );
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
      final joined = StudyCircleModel.fromJson(
        rawList.first as Map<String, dynamic>,
      );
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
    final published = SharedDeckModel.fromJson(
      rawList.first as Map<String, dynamic>,
    );
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
    fetchLeaderboards(track: track).then((entries) {
      for (final e in entries) {
        cache[e.userId] = e;
      }
      if (!streamController.isClosed) {
        streamController.add(_sortedLeaderboard(cache));
      }
    }).ignore();

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

  bool _isAutoProvisionedHashRoom(StudyRoomModel room) {
    final hexRegex = RegExp('^[0-9a-fA-F]{16,}');
    final title = room.title.trim();
    final subject = room.subject.trim();
    return hexRegex.hasMatch(title) ||
        hexRegex.hasMatch(subject) ||
        (title.contains('Study Hub Silent Focus Room') &&
            RegExp('[0-9a-fA-F]{8,}').hasMatch(title));
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
          .where((r) => !_isAutoProvisionedHashRoom(r))
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
    final effectiveTrack = (track != null && track.isNotEmpty && track != 'All')
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

  @override
  Future<bool> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
    String? details,
    String? postId,
  }) async {
    try {
      final userId = _userStorage?.getUserId();
      final reporterName = _userStorage?.getUserDisplayName() ?? 'Scholar';
      final payload = <String, dynamic>{
        'content_type': contentType,
        'content_id': contentId,
        'post_id': ?postId,
        'reporter_id': ?userId,
        'reporter_name': reporterName,
        'reason': reason,
        'details': ?details,
      };

      await _client.reportContent(payload);
      return true;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.reportContent failed',
          ),
        );
      }
      return false;
    }
  }

  static bool _isSubscriptionRpcAvailable = true;

  @override
  Future<bool> toggleForumPostSubscription(String postId) async {
    final storage = _localStorage;
    final current = await _getSubscribedForumPostIds();
    final isSubbed = current.contains(postId);
    final nextState = !isSubbed;
    final updated = Set<String>.from(current);
    if (isSubbed) {
      updated.remove(postId);
    } else {
      updated.add(postId);
    }
    if (storage != null) {
      await storage.savePreference(
        key: 'forum_subscribed_post_ids',
        data: jsonEncode(updated.toList()),
      );
    }

    final userId = _userStorage?.getUserId();

    // 1. Sync device token and FCM topic with NotificationService
    try {
      if (locator.isRegistered<NotificationService>()) {
        final notifService = locator<NotificationService>();
        if (nextState) {
          unawaited(notifService.subscribeToTopic('forum_post_$postId'));
          if (userId != null && userId.isNotEmpty) {
            unawaited(notifService.syncDeviceTokenWithBackend(userId: userId));
          }
        } else {
          unawaited(notifService.unsubscribeFromTopic('forum_post_$postId'));
        }
      }
    } on Object catch (_) {}

    bool? serverResult;

    // 2. Attempt Supabase stored procedure
    if (_isSubscriptionRpcAvailable) {
      try {
        final res = await _client.toggleForumPostSubscription({
          'p_post_id': postId,
          if (userId case final String uid) 'p_user_id': uid,
        });
        final data = res.data;
        if (data is bool) {
          serverResult = data;
        } else if (data is Map && data['is_subscribed'] is bool) {
          serverResult = data['is_subscribed'] as bool;
        } else if (data is Map && data['subscribed'] is bool) {
          serverResult = data['subscribed'] as bool;
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          _isSubscriptionRpcAvailable = false;
        }
      } on Object catch (_) {}
    }

    // 3. Direct REST table fallback on forum_post_subscriptions if RPC is unavailable/failed
    if (serverResult == null && userId != null && userId.isNotEmpty) {
      try {
        if (nextState) {
          await _client.insertForumPostSubscription({
            'user_id': userId,
            'post_id': postId,
          });
          serverResult = true;
        } else {
          await _client.deleteForumPostSubscription({
            'post_id': 'eq.$postId',
            'user_id': 'eq.$userId',
          });
          serverResult = false;
        }
      } on Object catch (_) {}
    }

    if (serverResult != null && serverResult != nextState) {
      final synced = Set<String>.from(updated);
      if (serverResult) {
        synced.add(postId);
      } else {
        synced.remove(postId);
      }
      if (storage != null) {
        await storage.savePreference(
          key: 'forum_subscribed_post_ids',
          data: jsonEncode(synced.toList()),
        );
      }
      return serverResult;
    }

    return nextState;
  }

  @override
  Future<bool> isForumPostSubscribed(String postId) async {
    final storage = _localStorage;
    final current = await _getSubscribedForumPostIds();
    final localSubscribed = current.contains(postId);

    final userId = _userStorage?.getUserId();
    bool? serverResult;

    if (_isSubscriptionRpcAvailable) {
      try {
        final res = await _client.isForumPostSubscribed({
          'p_post_id': postId,
          if (userId case final String uid) 'p_user_id': uid,
        });
        final data = res.data;
        if (data is bool) {
          serverResult = data;
        } else if (data is Map && data['is_subscribed'] is bool) {
          serverResult = data['is_subscribed'] as bool;
        } else if (data is Map && data['subscribed'] is bool) {
          serverResult = data['subscribed'] as bool;
        }
      } on DioException catch (dioErr) {
        if (dioErr.response?.statusCode == 404) {
          _isSubscriptionRpcAvailable = false;
        }
      } on Object catch (_) {}
    }

    // Direct REST table query fallback
    if (serverResult == null && userId != null && userId.isNotEmpty) {
      try {
        final res = await _client.fetchForumPostSubscriptions({
          'post_id': 'eq.$postId',
          'user_id': 'eq.$userId',
          'select': 'post_id',
        });
        final data = res.data;
        if (data is List) {
          serverResult = data.isNotEmpty;
        }
      } on Object catch (_) {}
    }

    if (serverResult != null) {
      if (serverResult != localSubscribed && storage != null) {
        final updated = Set<String>.from(current);
        if (serverResult) {
          updated.add(postId);
        } else {
          updated.remove(postId);
        }
        await storage.savePreference(
          key: 'forum_subscribed_post_ids',
          data: jsonEncode(updated.toList()),
        );
      }
      return serverResult;
    }

    return localSubscribed;
  }

  Future<Set<String>> _getSubscribedForumPostIds() async {
    try {
      final storage = _localStorage;
      if (storage == null) return {};
      final raw = storage.getPreference(key: 'forum_subscribed_post_ids');
      if (raw == null || raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return {};
    } on Object catch (_) {
      return {};
    }
  }

  @override
  Future<bool> toggleBookmarkForumPost(String postId) async {
    try {
      final storage = _localStorage;
      final current = await getBookmarkedForumPostIds();
      final isCurrentlyBookmarked = current.contains(postId);
      final updated = Set<String>.from(current);
      if (isCurrentlyBookmarked) {
        updated.remove(postId);
      } else {
        updated.add(postId);
      }
      if (storage != null) {
        await storage.savePreference(
          key: 'forum_bookmarked_post_ids',
          data: jsonEncode(updated.toList()),
        );
      }
      return !isCurrentlyBookmarked;
    } on Object catch (e, stack) {
      if (_crashlyticsService != null) {
        unawaited(
          _crashlyticsService!.recordError(
            e,
            stack,
            reason: 'CommunityRemoteDataSource.toggleBookmarkForumPost failed',
          ),
        );
      }
      return false;
    }
  }

  @override
  Future<Set<String>> getBookmarkedForumPostIds() async {
    try {
      final storage = _localStorage;
      if (storage == null) return {};
      final raw = storage.getPreference(key: 'forum_bookmarked_post_ids');
      if (raw == null || raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toSet();
      }
      return {};
    } on Object catch (_) {
      return {};
    }
  }
}
