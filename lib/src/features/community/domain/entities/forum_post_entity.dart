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
    this.downvotes = 0,
    this.userVote = 0,
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
  final int downvotes;
  final int userVote;
  final int repliesCount;
  final DateTime createdAt;
  final List<ForumReplyEntity> replies;

  int get netVotes => upvotes - downvotes;
  int get topLevelRepliesCount =>
      replies.isNotEmpty
          ? replies.where((r) => !r.isNested).length
          : repliesCount;

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
    int? downvotes,
    int? userVote,
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
      downvotes: downvotes ?? this.downvotes,
      userVote: userVote ?? this.userVote,
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
    downvotes,
    userVote,
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
    this.parentReplyId,
    this.authorAvatar,
    this.latexContent,
    this.isVerifiedSolution = false,
    this.upvotes = 0,
    this.downvotes = 0,
    this.userVote = 0,
  });

  final String id;
  final String postId;
  final String? parentReplyId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? latexContent;
  final bool isVerifiedSolution;
  final int upvotes;
  final int downvotes;
  final int userVote;
  final DateTime createdAt;

  int get netVotes => upvotes - downvotes;
  bool get isNested => parentReplyId != null && parentReplyId!.isNotEmpty;

  ForumReplyEntity copyWith({
    String? id,
    String? postId,
    String? parentReplyId,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? content,
    String? latexContent,
    bool? isVerifiedSolution,
    int? upvotes,
    int? downvotes,
    int? userVote,
    DateTime? createdAt,
  }) {
    return ForumReplyEntity(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      parentReplyId: parentReplyId ?? this.parentReplyId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      content: content ?? this.content,
      latexContent: latexContent ?? this.latexContent,
      isVerifiedSolution: isVerifiedSolution ?? this.isVerifiedSolution,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      userVote: userVote ?? this.userVote,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    postId,
    parentReplyId,
    authorId,
    authorName,
    authorAvatar,
    content,
    latexContent,
    isVerifiedSolution,
    upvotes,
    downvotes,
    userVote,
    createdAt,
  ];
}
