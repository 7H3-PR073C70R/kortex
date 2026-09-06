import 'dart:async';

import 'package:kortex/src/features/community/data/data_sources/community_local_data_source.dart';
import 'package:kortex/src/features/community/data/database/community_database_service.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';

class CommunityLocalDataSourceImpl implements CommunityLocalDataSource {
  CommunityLocalDataSourceImpl(this._databaseService);

  final CommunityDatabaseService _databaseService;

  @override
  Future<List<ForumPostModel>> getForumPosts({String? track}) async {
    final postRows = await _databaseService.queryForumPosts(track: track);
    final results = <ForumPostModel>[];

    for (final row in postRows) {
      final postId = row['id'] as String;
      final replyRows = await _databaseService.queryRepliesForPost(postId);
      final replies = replyRows.map(_replyFromRow).toList();
      results.add(_postFromRow(row, replies));
    }

    return results;
  }

  @override
  Future<ForumPostModel?> getForumPost(String id) async {
    final postRow = await _databaseService.queryForumPost(id);
    if (postRow == null) return null;

    final replyRows = await _databaseService.queryRepliesForPost(id);
    final replies = replyRows.map(_replyFromRow).toList();
    return _postFromRow(postRow, replies);
  }

  @override
  Future<List<ForumReplyModel>> getRepliesForPost(String postId) async {
    final replyRows = await _databaseService.queryRepliesForPost(postId);
    return replyRows.map(_replyFromRow).toList();
  }

  @override
  Future<void> saveForumPosts(List<ForumPostModel> posts) async {
    if (posts.isEmpty) return;

    final postRows = posts.map(_postToRow).toList();
    final replyRows = <Map<String, dynamic>>[];

    for (final post in posts) {
      for (final reply in post.replies) {
        replyRows.add(_replyToRow(reply, fallbackPostId: post.id));
      }
    }

    await _databaseService.batchUpsertPostsAndReplies(
      postRows,
      replies: replyRows,
    );
  }

  @override
  Future<void> saveForumPost(ForumPostModel post) async {
    await _databaseService.upsertPost(_postToRow(post));
    for (final reply in post.replies) {
      await _databaseService.upsertReply(
        _replyToRow(reply, fallbackPostId: post.id),
      );
    }
  }

  @override
  Future<void> saveForumReply(ForumReplyModel reply) async {
    await _databaseService.upsertReply(_replyToRow(reply));
  }

  @override
  Future<void> deleteForumPost(String postId) async {
    await _databaseService.deletePost(postId);
  }

  @override
  Future<void> deleteAllForumPosts() async {
    await _databaseService.deleteAllPosts();
  }

  // --- Row Mappers ---

  ForumPostModel _postFromRow(
    Map<String, dynamic> row, [
    List<ForumReplyModel> replies = const [],
  ]) {
    return ForumPostModel(
      id: row['id'] as String,
      authorId: row['author_id'] as String? ?? '',
      authorName: row['author_name'] as String? ?? 'Anonymous Peer',
      authorAvatar: row['author_avatar'] as String?,
      track: row['track'] as String? ?? 'General',
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      latexContent: row['latex_content'] as String?,
      upvotes: (row['upvotes'] as num?)?.toInt() ?? 0,
      repliesCount: (row['replies_count'] as num?)?.toInt() ?? replies.length,
      createdAt: DateTime.parse(
        row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      replies: replies,
    );
  }

  Map<String, dynamic> _postToRow(ForumPostModel post) {
    return {
      'id': post.id,
      'author_id': post.authorId,
      'author_name': post.authorName,
      'author_avatar': post.authorAvatar,
      'track': post.track,
      'title': post.title,
      'content': post.content,
      'latex_content': post.latexContent,
      'upvotes': post.upvotes,
      'replies_count':
          post.repliesCount > 0 ? post.repliesCount : post.replies.length,
      'created_at': post.createdAt.toIso8601String(),
    };
  }

  ForumReplyModel _replyFromRow(Map<String, dynamic> row) {
    return ForumReplyModel(
      id: row['id'] as String,
      postId: row['post_id'] as String? ?? '',
      authorId: row['author_id'] as String? ?? '',
      authorName: row['author_name'] as String? ?? 'Peer',
      authorAvatar: row['author_avatar'] as String?,
      content: row['content'] as String? ?? '',
      latexContent: row['latex_content'] as String?,
      upvotes: (row['upvotes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(
        row['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> _replyToRow(
    ForumReplyModel reply, {
    String? fallbackPostId,
  }) {
    return {
      'id': reply.id,
      'post_id': reply.postId.isNotEmpty ? reply.postId : (fallbackPostId ?? ''),
      'author_id': reply.authorId,
      'author_name': reply.authorName,
      'author_avatar': reply.authorAvatar,
      'content': reply.content,
      'latex_content': reply.latexContent,
      'upvotes': reply.upvotes,
      'created_at': reply.createdAt.toIso8601String(),
    };
  }
}
