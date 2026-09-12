import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/features/community/data/data_sources/community_local_data_source.dart';
import 'package:kortex/src/features/community/data/models/forum_post_model.dart';

class CommunityLocalDataSourceImpl implements CommunityLocalDataSource {
  CommunityLocalDataSourceImpl(this._database);

  final AppDatabase _database;

  @override
  Future<List<ForumPostModel>> getForumPosts({String? track}) async {
    final postEntries = await _database.getForumPosts(track: track);
    final results = <ForumPostModel>[];

    for (final entry in postEntries) {
      final replyEntries = await _database.getForumRepliesForPost(entry.id);
      final replies = replyEntries.map(_replyFromEntry).toList();
      results.add(_postFromEntry(entry, replies));
    }

    return results;
  }

  @override
  Future<ForumPostModel?> getForumPost(String id) async {
    final postEntry = await _database.getForumPostById(id);
    if (postEntry == null) return null;

    final replyEntries = await _database.getForumRepliesForPost(id);
    final replies = replyEntries.map(_replyFromEntry).toList();
    return _postFromEntry(postEntry, replies);
  }

  @override
  Future<List<ForumReplyModel>> getRepliesForPost(String postId) async {
    final replyEntries = await _database.getForumRepliesForPost(postId);
    return replyEntries.map(_replyFromEntry).toList();
  }

  @override
  Future<void> saveForumPosts(List<ForumPostModel> posts) async {
    if (posts.isEmpty) return;

    final postCompanions = posts.map(_postToCompanion).toList();
    final replyCompanions = <ForumRepliesCompanion>[];

    for (final post in posts) {
      for (final reply in post.replies) {
        replyCompanions.add(_replyToCompanion(reply, fallbackPostId: post.id));
      }
    }

    await _database.batchUpsertForumPostsAndReplies(
      posts: postCompanions,
      replies: replyCompanions,
    );
  }

  @override
  Future<void> saveForumPost(ForumPostModel post) async {
    await _database.upsertForumPost(_postToCompanion(post));
    for (final reply in post.replies) {
      await _database.upsertForumReply(
        _replyToCompanion(reply, fallbackPostId: post.id),
      );
    }
  }

  @override
  Future<void> saveForumReply(ForumReplyModel reply) async {
    await _database.upsertForumReply(_replyToCompanion(reply));
  }

  @override
  Future<void> deleteForumPost(String postId) async {
    await _database.deleteForumPostById(postId);
  }

  @override
  Future<void> deleteAllForumPosts() async {
    await _database.deleteAllForumPosts();
  }

  // --- Mappers ---

  ForumPostModel _postFromEntry(
    ForumPostEntry entry, [
    List<ForumReplyModel> replies = const [],
  ]) {
    return ForumPostModel(
      id: entry.id,
      authorId: entry.authorId,
      authorName: entry.authorName,
      authorAvatar: entry.authorAvatar,
      track: entry.track,
      title: entry.title,
      content: entry.content,
      latexContent: entry.latexContent,
      upvotes: entry.upvotes,
      repliesCount: entry.repliesCount > 0
          ? entry.repliesCount
          : replies.length,
      createdAt: entry.createdAt,
      replies: replies,
    );
  }

  ForumPostsCompanion _postToCompanion(ForumPostModel post) {
    return ForumPostsCompanion(
      id: Value(post.id),
      authorId: Value(post.authorId),
      authorName: Value(post.authorName),
      authorAvatar: Value(post.authorAvatar),
      track: Value(post.track),
      title: Value(post.title),
      content: Value(post.content),
      latexContent: Value(post.latexContent),
      upvotes: Value(post.upvotes),
      repliesCount: Value(
        post.repliesCount > 0 ? post.repliesCount : post.replies.length,
      ),
      createdAt: Value(post.createdAt),
      cachedAt: Value(DateTime.now()),
    );
  }

  ForumReplyModel _replyFromEntry(ForumReplyEntry entry) {
    return ForumReplyModel(
      id: entry.id,
      postId: entry.postId,
      authorId: entry.authorId,
      authorName: entry.authorName,
      authorAvatar: entry.authorAvatar,
      content: entry.content,
      latexContent: entry.latexContent,
      upvotes: entry.upvotes,
      createdAt: entry.createdAt,
    );
  }

  ForumRepliesCompanion _replyToCompanion(
    ForumReplyModel reply, {
    String? fallbackPostId,
  }) {
    return ForumRepliesCompanion(
      id: Value(reply.id),
      postId: Value(
        reply.postId.isNotEmpty ? reply.postId : (fallbackPostId ?? ''),
      ),
      authorId: Value(reply.authorId),
      authorName: Value(reply.authorName),
      authorAvatar: Value(reply.authorAvatar),
      content: Value(reply.content),
      latexContent: Value(reply.latexContent),
      upvotes: Value(reply.upvotes),
      createdAt: Value(reply.createdAt),
      cachedAt: Value(DateTime.now()),
    );
  }
}
