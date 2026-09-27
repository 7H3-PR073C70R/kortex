import 'package:equatable/equatable.dart';
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
  });

  final String id;
  final OfflineActionType actionType;
  final DateTime createdAt;
  final ForumPostEntity? postPayload;
  final ForumReplyEntity? replyPayload;
  final String? postId;
  final int? voteDirection;

  @override
  List<Object?> get props => [
        id,
        actionType,
        createdAt,
        postPayload,
        replyPayload,
        postId,
        voteDirection,
      ];
}

/// Offline Synchronization Queue Manager for Forum Threads & Interactions.
///
/// Stores offline actions in memory / local state and safely replays them
/// sequentially when network connection returns.
class ForumOfflineSyncQueue {
  ForumOfflineSyncQueue();

  final List<QueuedForumAction> _queue = [];

  List<QueuedForumAction> get pendingActions => List.unmodifiable(_queue);
  int get queueLength => _queue.length;
  bool get hasPendingActions => _queue.isNotEmpty;

  void enqueuePost(ForumPostEntity post) {
    _queue.add(
      QueuedForumAction(
        id: 'queue-post-${post.id}-${DateTime.now().millisecondsSinceEpoch}',
        actionType: OfflineActionType.createPost,
        postPayload: post,
        createdAt: DateTime.now(),
      ),
    );
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
  }

  void clearQueue() {
    _queue.clear();
  }

  /// Sequentially replays all pending offline actions against the repository.
  ///
  /// Returns the number of successfully processed actions.
  Future<int> processSyncQueue(CommunityRepository repository) async {
    if (_queue.isEmpty) return 0;

    var successCount = 0;
    final remainingActions = <QueuedForumAction>[];

    for (final action in _queue) {
      try {
        switch (action.actionType) {
          case OfflineActionType.createPost:
            if (action.postPayload != null) {
              final res = await repository.createForumPost(
                track: action.postPayload!.track,
                title: action.postPayload!.title,
                content: action.postPayload!.content,
                isQuestion: action.postPayload!.isQuestion,
                syllabusTag: action.postPayload!.syllabusTag,
                mediaUrls: action.postPayload!.mediaUrls,
                voiceNoteUrl: action.postPayload!.voiceNoteUrl,
                voiceNoteDurationSeconds:
                    action.postPayload!.voiceNoteDurationSeconds,
              );
              res.fold(
                (_) => remainingActions.add(action),
                (_) => successCount++,
              );
            }
          case OfflineActionType.createReply:
            if (action.replyPayload != null) {
              final res = await repository.replyToForumPost(
                postId: action.replyPayload!.postId,
                parentReplyId: action.replyPayload!.parentReplyId,
                content: action.replyPayload!.content,
                mediaUrls: action.replyPayload!.mediaUrls,
                voiceNoteUrl: action.replyPayload!.voiceNoteUrl,
                voiceNoteDurationSeconds:
                    action.replyPayload!.voiceNoteDurationSeconds,
              );
              res.fold(
                (_) => remainingActions.add(action),
                (_) => successCount++,
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
                (_) => remainingActions.add(action),
                (_) => successCount++,
              );
            }
        }
      } on Object catch (_) {
        remainingActions.add(action);
      }
    }

    _queue
      ..clear()
      ..addAll(remainingActions);

    return successCount;
  }
}
