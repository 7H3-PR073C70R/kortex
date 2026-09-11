import 'package:equatable/equatable.dart';

/// Represents a discussion thread post in a track forum.
class ForumPostEntity extends Equatable {
  const ForumPostEntity({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.track,
    required this.title,
    required this.content,
    required this.createdAt,
    this.authorAvatar,
    this.latexContent,
    this.isQuestion = false,
    this.isVerifiedSolution = false,
    this.syllabusTag = 'General',
    this.upvotes = 0,
    this.repliesCount = 0,
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
  final bool isQuestion;
  final bool isVerifiedSolution;
  final String syllabusTag;
  final int upvotes;
  final int repliesCount;
  final DateTime createdAt;
  final List<ForumReplyEntity> replies;

  ForumPostEntity copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? track,
    String? title,
    String? content,
    String? latexContent,
    bool? isQuestion,
    bool? isVerifiedSolution,
    String? syllabusTag,
    int? upvotes,
    int? repliesCount,
    DateTime? createdAt,
    List<ForumReplyEntity>? replies,
  }) {
    return ForumPostEntity(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      track: track ?? this.track,
      title: title ?? this.title,
      content: content ?? this.content,
      latexContent: latexContent ?? this.latexContent,
      isQuestion: isQuestion ?? this.isQuestion,
      isVerifiedSolution: isVerifiedSolution ?? this.isVerifiedSolution,
      syllabusTag: syllabusTag ?? this.syllabusTag,
      upvotes: upvotes ?? this.upvotes,
      repliesCount: repliesCount ?? this.repliesCount,
      createdAt: createdAt ?? this.createdAt,
      replies: replies ?? this.replies,
    );
  }

  @override
  List<Object?> get props => [
    id,
    authorId,
    authorName,
    authorAvatar,
    track,
    title,
    content,
    latexContent,
    isQuestion,
    isVerifiedSolution,
    syllabusTag,
    upvotes,
    repliesCount,
    createdAt,
    replies,
  ];
}

/// Represents a nested reply in a forum thread.
class ForumReplyEntity extends Equatable {
  const ForumReplyEntity({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorAvatar,
    this.latexContent,
    this.isVerifiedSolution = false,
    this.upvotes = 0,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? latexContent;
  final bool isVerifiedSolution;
  final int upvotes;
  final DateTime createdAt;

  ForumReplyEntity copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    String? latexContent,
    bool? isVerifiedSolution,
    int? upvotes,
    DateTime? createdAt,
  }) {
    return ForumReplyEntity(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      latexContent: latexContent ?? this.latexContent,
      isVerifiedSolution: isVerifiedSolution ?? this.isVerifiedSolution,
      upvotes: upvotes ?? this.upvotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    authorId,
    authorName,
    authorAvatar,
    content,
    latexContent,
    isVerifiedSolution,
    upvotes,
    createdAt,
  ];
}
