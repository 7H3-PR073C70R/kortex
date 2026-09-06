import 'package:kortex/src/features/community/data/models/forum_post_model.dart';

abstract class CommunityLocalDataSource {
  /// Retrieves cached forum posts, optionally filtered by academic [track].
  Future<List<ForumPostModel>> getForumPosts({String? track});

  /// Retrieves a specific forum post with its cached replies.
  Future<ForumPostModel?> getForumPost(String id);

  /// Retrieves all cached replies for a given [postId].
  Future<List<ForumReplyModel>> getRepliesForPost(String postId);

  /// Saves or updates a batch of forum posts and their nested replies in SQLite.
  Future<void> saveForumPosts(List<ForumPostModel> posts);

  /// Saves or updates a single forum post in SQLite.
  Future<void> saveForumPost(ForumPostModel post);

  /// Saves or updates a single forum reply in SQLite.
  Future<void> saveForumReply(ForumReplyModel reply);

  /// Deletes a forum post and cascades to its replies.
  Future<void> deleteForumPost(String postId);

  /// Clears all forum posts and replies from the local SQLite cache.
  Future<void> deleteAllForumPosts();
}
