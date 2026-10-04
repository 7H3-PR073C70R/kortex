import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/domain/repositories/community_repository.dart';

/// Represents the type of queued offline community action.
enum OfflineActionType { createPost, createReply, upvotePost, downvotePost }

/// An offline pending forum payload queued when network connection is unavailable.
class QueuedForumAction extends Equatable {
  const QueuedForumAction({
    required this.id,
    required this.actionType,
    required this.createdAt,
    this.postPayload,
    this.replyPayload,
    this.postId,
    this.voteDirection,
    this.retryCount = 0,
    this.maxRetries = 3,
    this.lastAttemptAt,
    this.lastError,
  });

  factory QueuedForumAction.fromJson(Map<String, dynamic> json) {
    final actionTypeName = json['actionType'] as String? ?? 'createPost';
    final actionType = OfflineActionType.values.firstWhere(
      (e) => e.name == actionTypeName,
      orElse: () => OfflineActionType.createPost,
    );

    ForumPostEntity? post;
    if (json['postPayload'] != null) {
      try {
        post = ForumPostModel.fromJson(
          Map<String, dynamic>.from(json['postPayload'] as Map),
        ).toEntity();
      } on Object catch (_) {}
    }

    ForumReplyEntity? reply;
    if (json['replyPayload'] != null) {
      try {
        reply = ForumReplyModel.fromJson(
          Map<String, dynamic>.from(json['replyPayload'] as Map),
        ).toEntity();
      } on Object catch (_) {}
    }

    return QueuedForumAction(
      id: json['id'] as String? ?? 'queue-${DateTime.now().millisecondsSinceEpoch}',
      actionType: actionType,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      postPayload: post,
      replyPayload: reply,
      postId: json['postId'] as String?,
      voteDirection: json['voteDirection'] as int?,
      retryCount: json['retryCount'] as int? ?? 0,
      maxRetries: json['maxRetries'] as int? ?? 3,
      lastAttemptAt: json['lastAttemptAt'] != null
          ? DateTime.tryParse(json['lastAttemptAt'] as String)
          : null,
      lastError: json['lastError'] as String?,
    );
  }

  final String id;
  final OfflineActionType actionType;
  final DateTime createdAt;
  final ForumPostEntity? postPayload;
  final ForumReplyEntity? replyPayload;
  final String? postId;
  final int? voteDirection;
  final int retryCount;
  final int maxRetries;
  final DateTime? lastAttemptAt;
  final String? lastError;

  bool get isMaxRetriesExceeded => retryCount >= maxRetries;

  QueuedForumAction copyWith({
    String? id,
    OfflineActionType? actionType,
    DateTime? createdAt,
    ForumPostEntity? postPayload,
    ForumReplyEntity? replyPayload,
    String? postId,
    int? voteDirection,
    int? retryCount,
    int? maxRetries,
    DateTime? lastAttemptAt,
    String? lastError,
  }) {
    return QueuedForumAction(
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      createdAt: createdAt ?? this.createdAt,
      postPayload: postPayload ?? this.postPayload,
      replyPayload: replyPayload ?? this.replyPayload,
      postId: postId ?? this.postId,
      voteDirection: voteDirection ?? this.voteDirection,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'actionType': actionType.name,
      'createdAt': createdAt.toIso8601String(),
      'postPayload': postPayload != null
          ? ForumPostModel.fromEntity(postPayload!).toJson()
          : null,
      'replyPayload': replyPayload != null
          ? ForumReplyModel.fromEntity(replyPayload!).toJson()
          : null,
      'postId': postId,
      'voteDirection': voteDirection,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'lastAttemptAt': lastAttemptAt?.toIso8601String(),
      'lastError': lastError,
    };
  }

  @override
  List<Object?> get props => [
        id,
        actionType,
        createdAt,
        postPayload,
        replyPayload,
        postId,
        voteDirection,
        retryCount,
        maxRetries,
        lastAttemptAt,
        lastError,
      ];
}

/// Offline Synchronization Queue Manager for Forum Threads & Interactions.
///
/// Stores offline actions with local storage persistence and replays them
/// with exponential backoff and poison-pill protection when network returns.
class ForumOfflineSyncQueue {
  ForumOfflineSyncQueue({LocalStorageService? localStorageService})
      : _localStorage = localStorageService {
    _loadPersistedQueue();
  }

  static const String _storageKey = 'kortex_offline_forum_sync_queue';
  final LocalStorageService? _localStorage;
  final List<QueuedForumAction> _queue = [];
  final List<QueuedForumAction> _discardedActions = [];

  LocalStorageService? get _effectiveStorage {
    if (_localStorage != null) return _localStorage;
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        return locator<LocalStorageService>();
      }
    } on Object catch (_) {}
    return null;
  }

  List<QueuedForumAction> get pendingActions => List.unmodifiable(_queue);
  List<QueuedForumAction> get discardedActions =>
      List.unmodifiable(_discardedActions);
  int get queueLength => _queue.length;
  bool get hasPendingActions => _queue.isNotEmpty;

  void _loadPersistedQueue() {
    try {
      final storage = _effectiveStorage;
      if (storage != null) {
        final rawJson = storage.getPreference(key: _storageKey);
        if (rawJson != null && rawJson.trim().isNotEmpty) {
          final decoded = jsonDecode(rawJson);
          if (decoded is List) {
            _queue.clear();
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                _queue.add(QueuedForumAction.fromJson(item));
              } else if (item is Map) {
                _queue.add(
                  QueuedForumAction.fromJson(Map<String, dynamic>.from(item)),
                );
              }
            }
          }
        }
      }
    } on Object catch (e) {
      debugPrint('Failed to load persisted offline forum queue: $e');
    }
  }

  Future<void> _persistQueue() async {
    try {
      final storage = _effectiveStorage;
      if (storage != null) {
        if (_queue.isEmpty) {
          await storage.deletePreference(key: _storageKey);
        } else {
          final jsonStr =
              jsonEncode(_queue.map((action) => action.toJson()).toList());
          await storage.savePreference(key: _storageKey, data: jsonStr);
        }
      }
    } on Object catch (e) {
      debugPrint('Failed to persist offline forum queue: $e');
    }
  }

  void enqueuePost(ForumPostEntity post) {
    _queue.add(
      QueuedForumAction(
        id: 'queue-post-${post.id}-${DateTime.now().millisecondsSinceEpoch}',
        actionType: OfflineActionType.createPost,
        postPayload: post,
        createdAt: DateTime.now(),
      ),
    );
    unawaited(_persistQueue());
  }

  void enqueueReply(ForumReplyEntity reply) {
    _queue.add(
      QueuedForumAction(
        id: 'queue-reply-${reply.id}-${DateTime.now().millisecondsSinceEpoch}',
        actionType: OfflineActionType.createReply,
        replyPayload: reply,
        createdAt: DateTime.now(),
      ),
    );
    unawaited(_persistQueue());
  }

  void enqueueVote({required String postId, required int voteDirection}) {
    _queue.add(
      QueuedForumAction(
        id: 'queue-vote-$postId-${DateTime.now().millisecondsSinceEpoch}',
        actionType: voteDirection > 0
            ? OfflineActionType.upvotePost
            : OfflineActionType.downvotePost,
        postId: postId,
        voteDirection: voteDirection,
        createdAt: DateTime.now(),
      ),
    );
    unawaited(_persistQueue());
  }

  void clearQueue() {
    _queue.clear();
    unawaited(_persistQueue());
  }

  /// Calculates the backoff threshold in seconds based on retry attempt count.
  static int calculateBackoffSeconds(int retryCount) {
    if (retryCount <= 0) return 0;
    // Exponential backoff: 2s, 4s, 8s, capped at 60s
    return math.min(60, math.pow(2, retryCount).toInt() * 2);
  }

  /// Sequentially replays all pending offline actions against the repository.
  ///
  /// Applies exponential backoff for retried actions and safely discards
  /// poison-pill actions that exceed [QueuedForumAction.maxRetries].
  /// Returns the number of successfully processed actions.
  Future<int> processSyncQueue(
    CommunityRepository repository, {
    bool forceRetry = false,
  }) async {
    if (_queue.isEmpty) return 0;

    var successCount = 0;
    final remainingActions = <QueuedForumAction>[];
    final now = DateTime.now();

    for (final action in List<QueuedForumAction>.from(_queue)) {
      // Check exponential backoff delay before retrying
      if (!forceRetry && action.lastAttemptAt != null && action.retryCount > 0) {
        final backoffDelay = calculateBackoffSeconds(action.retryCount);
        if (now.difference(action.lastAttemptAt!).inSeconds < backoffDelay) {
          // Still within backoff window, defer to next cycle
          remainingActions.add(action);
          continue;
        }
      }

      var wasSuccessful = false;
      String? errorMessage;

      try {
        switch (action.actionType) {
          case OfflineActionType.createPost:
            if (action.postPayload != null) {
              final payload = action.postPayload!;
              // Filter out local media file paths that no longer exist
              final validMediaUrls = payload.mediaUrls.where((path) {
                if (path.startsWith('http://') || path.startsWith('https://')) {
                  return true;
                }
                return File(path).existsSync();
              }).toList();

              var validVoiceUrl = payload.voiceNoteUrl;
              if (validVoiceUrl != null &&
                  !validVoiceUrl.startsWith('http://') &&
                  !validVoiceUrl.startsWith('https://')) {
                if (!File(validVoiceUrl).existsSync()) {
                  validVoiceUrl = null;
                }
              }

              final res = await repository.createForumPost(
                track: payload.track,
                title: payload.title,
                content: payload.content,
                isQuestion: payload.isQuestion,
                syllabusTag: payload.syllabusTag,
                mediaUrls: validMediaUrls,
                voiceNoteUrl: validVoiceUrl,
                voiceNoteDurationSeconds: payload.voiceNoteDurationSeconds,
              );
              res.fold(
                (failure) => errorMessage = failure.message,
                (_) => wasSuccessful = true,
              );
            }

          case OfflineActionType.createReply:
            if (action.replyPayload != null) {
              final payload = action.replyPayload!;
              final validMediaUrls = payload.mediaUrls.where((path) {
                if (path.startsWith('http://') || path.startsWith('https://')) {
                  return true;
                }
                return File(path).existsSync();
              }).toList();

              var validVoiceUrl = payload.voiceNoteUrl;
              if (validVoiceUrl != null &&
                  !validVoiceUrl.startsWith('http://') &&
                  !validVoiceUrl.startsWith('https://')) {
                if (!File(validVoiceUrl).existsSync()) {
                  validVoiceUrl = null;
                }
              }

              final res = await repository.replyToForumPost(
                postId: payload.postId,
                parentReplyId: payload.parentReplyId,
                content: payload.content,
                mediaUrls: validMediaUrls,
                voiceNoteUrl: validVoiceUrl,
                voiceNoteDurationSeconds: payload.voiceNoteDurationSeconds,
              );
              res.fold(
                (failure) => errorMessage = failure.message,
                (_) => wasSuccessful = true,
              );
            }

          case OfflineActionType.upvotePost:
          case OfflineActionType.downvotePost:
            if (action.postId != null) {
              final res = await repository.voteForumPost(
                postId: action.postId!,
                voteDirection: action.voteDirection ?? 1,
              );
              res.fold(
                (failure) => errorMessage = failure.message,
                (_) => wasSuccessful = true,
              );
            }
        }
      } on Object catch (e) {
        errorMessage = e.toString();
        wasSuccessful = false;
      }

      if (wasSuccessful) {
        successCount++;
      } else {
        final newRetryCount = action.retryCount + 1;
        final updatedAction = action.copyWith(
          retryCount: newRetryCount,
          lastAttemptAt: now,
          lastError: errorMessage ?? 'Network or service error during sync',
        );

        if (newRetryCount >= action.maxRetries) {
          // Exceeded max retries: discard to avoid poison-pill queue block
          _discardedActions.add(updatedAction);
          debugPrint(
            'Action ${action.id} discarded after ${action.maxRetries} failed attempts: $errorMessage',
          );
        } else {
          remainingActions.add(updatedAction);
        }
      }
    }

    _queue
      ..clear()
      ..addAll(remainingActions);

    await _persistQueue();
    return successCount;
  }
}
