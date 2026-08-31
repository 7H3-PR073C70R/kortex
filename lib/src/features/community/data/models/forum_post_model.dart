import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';

class ForumPostModel {
  const ForumPostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.track,
    required this.title,
    required this.content,
    this.latexContent,
    this.upvotes = 0,
    this.repliesCount = 0,
    required this.createdAt,
    this.replies = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String track;
  final String title;
  final String content;
  final String? latexContent;
  final int upvotes;
  final int repliesCount;
  final DateTime createdAt;
  final List<ForumReplyModel> replies;

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['forum_replies'] as List<dynamic>? ?? [];
    return ForumPostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Anonymous Peer',
      authorAvatar: json['author_avatar'] as String?,
      track: json['track'] as String? ?? 'General',
      title: json['title'] as String,
      content: json['content'] as String,
      latexContent: json['latex_content'] as String?,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      repliesCount: (json['replies_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      replies: rawReplies
          .map((r) => ForumReplyModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'track': track,
      'title': title,
      'content': content,
      'latex_content': latexContent,
      'upvotes': upvotes,
      'replies_count': repliesCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ForumPostEntity toEntity() {
    return ForumPostEntity(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      track: track,
      title: title,
      content: content,
      latexContent: latexContent,
      upvotes: upvotes,
      repliesCount: repliesCount,
      createdAt: createdAt,
      replies: replies.map((r) => r.toEntity()).toList(),
    );
  }
}

class ForumReplyModel {
  const ForumReplyModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.latexContent,
    this.upvotes = 0,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? latexContent;
  final int upvotes;
  final DateTime createdAt;

  factory ForumReplyModel.fromJson(Map<String, dynamic> json) {
    return ForumReplyModel(
      id: json['id'] as String,
      postId: json['post_id'] as String? ?? '',
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Peer',
      authorAvatar: json['author_avatar'] as String?,
      content: json['content'] as String,
      latexContent: json['latex_content'] as String?,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'content': content,
      'latex_content': latexContent,
      'upvotes': upvotes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ForumReplyEntity toEntity() {
    return ForumReplyEntity(
      id: id,
      postId: postId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      latexContent: latexContent,
      upvotes: upvotes,
      createdAt: createdAt,
    );
  }
}
