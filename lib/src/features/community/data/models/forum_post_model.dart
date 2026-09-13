import 'dart:convert';
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
    this.isQuestion = false,
    this.isVerifiedSolution = false,
    this.syllabusTag = 'General',
    this.upvotes = 0,
    this.downvotes = 0,
    this.userVote = 0,
    this.repliesCount = 0,
    this.tags = const [],
    this.mediaUrls = const [],
    this.voiceNoteUrl,
    this.voiceNoteDurationSeconds,
    this.socraticHint,
    this.socraticHintGeneratedAt,
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
  final bool isQuestion;
  final bool isVerifiedSolution;
  final String syllabusTag;
  final int upvotes;
  final int downvotes;
  final int userVote;
  final int repliesCount;
  final List<String> tags;
  final List<String> mediaUrls;
  final String? voiceNoteUrl;
  final int? voiceNoteDurationSeconds;
  final String? socraticHint;
  final DateTime? socraticHintGeneratedAt;
  final DateTime createdAt;
  final List<ForumReplyModel> replies;

  int get netVotes => upvotes - downvotes;
  int get topLevelRepliesCount =>
      replies.isNotEmpty
          ? replies.where((r) => !r.isNested).length
          : repliesCount;

  static List<String> extractMediaUrls(String content, [dynamic rawMedia]) {
    final results = <String>[];

    // 1. Explicit raw media parameter (List or JSON String)
    if (rawMedia is List) {
      for (final item in rawMedia) {
        final s = item?.toString().trim();
        if (s != null && s.isNotEmpty && !results.contains(s)) {
          results.add(s);
        }
      }
    } else if (rawMedia is String && rawMedia.trim().isNotEmpty) {
      final trimmed = rawMedia.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (final item in decoded) {
              final s = item?.toString().trim();
              if (s != null && s.isNotEmpty && !results.contains(s)) {
                results.add(s);
              }
            }
          }
        } catch (_) {
          final parts = trimmed
              .replaceAll(RegExp(r'[\[\]"]'), '')
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty);
          for (final part in parts) {
            if (!results.contains(part)) results.add(part);
          }
        }
      } else {
        final parts = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final part in parts) {
          if (!results.contains(part)) results.add(part);
        }
      }
    }

    // 2. Metadata HTML comments embedded in content: <!-- media: [...] -->
    final commentMatch = RegExp(r'<!--\s*media:\s*(\[[\s\S]*?\])\s*-->').firstMatch(content);
    if (commentMatch != null) {
      try {
        final decoded = jsonDecode(commentMatch.group(1)!);
        if (decoded is List) {
          for (final item in decoded) {
            final s = item?.toString().trim();
            if (s != null && s.isNotEmpty && !results.contains(s)) {
              results.add(s);
            }
          }
        }
      } catch (_) {}
    }

    // 3. Markdown images embedded in content: ![alt](url)
    final mdMatches = RegExp(r'!\[.*?\]\((https?:\/\/[^\s\)]+|[^\s\)]+\.(?:png|jpg|jpeg|webp|gif|svg))\)').allMatches(content);
    for (final match in mdMatches) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty && !results.contains(url)) {
        results.add(url);
      }
    }

    return results;
  }

  static List<String> extractTags(String content, [dynamic rawTags]) {
    final results = <String>[];

    // 1. Explicit raw tags parameter
    if (rawTags is List) {
      for (final item in rawTags) {
        final s = item?.toString().trim();
        if (s != null && s.isNotEmpty && !results.contains(s)) {
          results.add(s);
        }
      }
    } else if (rawTags is String && rawTags.trim().isNotEmpty) {
      final trimmed = rawTags.trim();
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is List) {
            for (final item in decoded) {
              final s = item?.toString().trim();
              if (s != null && s.isNotEmpty && !results.contains(s)) {
                results.add(s);
              }
            }
          }
        } catch (_) {}
      } else {
        final parts = trimmed.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final part in parts) {
          if (!results.contains(part)) results.add(part);
        }
      }
    }

    // 2. Metadata HTML comments embedded in content: <!-- tags: [...] -->
    final commentMatch = RegExp(r'<!--\s*tags:\s*(\[[\s\S]*?\])\s*-->').firstMatch(content);
    if (commentMatch != null) {
      try {
        final decoded = jsonDecode(commentMatch.group(1)!);
        if (decoded is List) {
          for (final item in decoded) {
            final s = item?.toString().trim();
            if (s != null && s.isNotEmpty && !results.contains(s)) {
              results.add(s);
            }
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to Hashtags in content if empty
    if (results.isEmpty) {
      final hashMatches = RegExp(r'(?:^|\s)#([a-zA-Z0-9_\-]+)').allMatches(content);
      for (final match in hashMatches) {
        final tag = match.group(1)?.trim();
        if (tag != null && tag.isNotEmpty && !RegExp(r'^\d+$').hasMatch(tag) && !results.contains(tag)) {
          results.add(tag);
        }
      }
    }

    return results;
  }

  static ({String? url, int? duration}) extractVoiceNote(
    String content, {
    String? rawUrl,
    int? rawDuration,
  }) {
    if (rawUrl != null && rawUrl.trim().isNotEmpty) {
      return (url: rawUrl.trim(), duration: rawDuration);
    }

    final voiceMatch = RegExp(
      r'<!--\s*voice:\s*(\S+?)(?:\s+duration:(\d+))?\s*-->',
    ).firstMatch(content);
    if (voiceMatch != null) {
      final url = voiceMatch.group(1)?.trim();
      final durStr = voiceMatch.group(2);
      final dur = durStr != null ? int.tryParse(durStr) : null;
      return (url: url, duration: dur ?? rawDuration);
    }

    return (url: null, duration: null);
  }

  factory ForumPostModel.fromJson(Map<String, dynamic> json) {
    final rawReplies = json['forum_replies'] as List<dynamic>? ?? [];
    final parsedReplies = rawReplies
        .map((r) => ForumReplyModel.fromJson(r as Map<String, dynamic>))
        .toList();
    final topLevelCount = parsedReplies.where((r) => !r.isNested).length;
    final explicitCount = (json['replies_count'] as num?)?.toInt() ??
        (json['reply_count'] as num?)?.toInt() ??
        (json['comments_count'] as num?)?.toInt();
    final repliesCount = explicitCount != null && explicitCount > 0
        ? explicitCount
        : topLevelCount;

    final content = json['content'] as String? ?? '';
    final parsedTags = extractTags(content, json['tags']);
    final parsedMedia = extractMediaUrls(
      content,
      json['media_urls'] ?? json['mediaUrls'] ?? json['image_url'] ?? json['imageUrl'],
    );
    final voiceNote = extractVoiceNote(
      content,
      rawUrl: json['voice_note_url'] as String? ?? json['voiceNoteUrl'] as String?,
      rawDuration: (json['voice_note_duration_seconds'] as num?)?.toInt() ??
          (json['voiceNoteDurationSeconds'] as num?)?.toInt(),
    );

    return ForumPostModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Anonymous Peer',
      authorAvatar: json['author_avatar'] as String?,
      track: json['track'] as String? ?? 'General',
      title: json['title'] as String,
      content: content,
      latexContent: json['latex_content'] as String?,
      isQuestion: json['is_question'] as bool? ?? false,
      isVerifiedSolution: json['is_verified_solution'] as bool? ?? false,
      syllabusTag: json['syllabus_tag'] as String? ?? 'General',
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      userVote: (json['user_vote'] as num?)?.toInt() ??
          (json['userVote'] as num?)?.toInt() ??
          0,
      repliesCount: repliesCount,
      tags: parsedTags,
      mediaUrls: parsedMedia,
      voiceNoteUrl: voiceNote.url,
      voiceNoteDurationSeconds: voiceNote.duration,
      socraticHint: json['socratic_hint'] as String? ?? json['socraticHint'] as String?,
      socraticHintGeneratedAt: json['socratic_hint_generated_at'] != null
          ? DateTime.tryParse(json['socratic_hint_generated_at'] as String)
          : (json['socraticHintGeneratedAt'] != null
              ? DateTime.tryParse(json['socraticHintGeneratedAt'] as String)
              : null),
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      replies: parsedReplies,
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
      'is_question': isQuestion,
      'is_verified_solution': isVerifiedSolution,
      'syllabus_tag': syllabusTag,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'user_vote': userVote,
      'replies_count': repliesCount,
      'tags': tags,
      'media_urls': mediaUrls,
      if (voiceNoteUrl != null) 'voice_note_url': voiceNoteUrl,
      if (voiceNoteDurationSeconds != null)
        'voice_note_duration_seconds': voiceNoteDurationSeconds,
      if (socraticHint != null) 'socratic_hint': socraticHint,
      if (socraticHintGeneratedAt != null)
        'socratic_hint_generated_at': socraticHintGeneratedAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'forum_replies': replies.map((r) => r.toJson()).toList(),
    };
  }

  ForumPostModel copyWith({
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
    List<String>? tags,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    String? socraticHint,
    DateTime? socraticHintGeneratedAt,
    DateTime? createdAt,
    List<ForumReplyModel>? replies,
  }) {
    return ForumPostModel(
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
      tags: tags ?? this.tags,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
      voiceNoteDurationSeconds:
          voiceNoteDurationSeconds ?? this.voiceNoteDurationSeconds,
      socraticHint: socraticHint ?? this.socraticHint,
      socraticHintGeneratedAt:
          socraticHintGeneratedAt ?? this.socraticHintGeneratedAt,
      createdAt: createdAt ?? this.createdAt,
      replies: replies ?? this.replies,
    );
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
      isQuestion: isQuestion,
      isVerifiedSolution: isVerifiedSolution,
      syllabusTag: syllabusTag,
      upvotes: upvotes,
      downvotes: downvotes,
      userVote: userVote,
      repliesCount: repliesCount,
      tags: tags,
      mediaUrls: mediaUrls,
      voiceNoteUrl: voiceNoteUrl,
      voiceNoteDurationSeconds: voiceNoteDurationSeconds,
      socraticHint: socraticHint,
      socraticHintGeneratedAt: socraticHintGeneratedAt,
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
    this.parentReplyId,
    this.authorAvatar,
    required this.content,
    this.latexContent,
    this.isVerifiedSolution = false,
    this.upvotes = 0,
    this.downvotes = 0,
    this.userVote = 0,
    this.repliesCount = 0,
    this.mediaUrls = const [],
    this.voiceNoteUrl,
    this.voiceNoteDurationSeconds,
    required this.createdAt,
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
  final int repliesCount;
  final List<String> mediaUrls;
  final String? voiceNoteUrl;
  final int? voiceNoteDurationSeconds;
  final DateTime createdAt;

  int get netVotes => upvotes - downvotes;
  bool get isNested => parentReplyId != null && parentReplyId!.isNotEmpty;

  static List<String> extractMediaUrls(String content, [dynamic rawMedia]) {
    return ForumPostModel.extractMediaUrls(content, rawMedia);
  }

  static ({String? url, int? duration}) extractVoiceNote(
    String content, {
    String? rawUrl,
    int? rawDuration,
  }) {
    return ForumPostModel.extractVoiceNote(
      content,
      rawUrl: rawUrl,
      rawDuration: rawDuration,
    );
  }

  factory ForumReplyModel.fromJson(Map<String, dynamic> json) {
    final content = json['content'] as String? ?? '';
    final parsedMedia = extractMediaUrls(
      content,
      json['media_urls'] ?? json['mediaUrls'] ?? json['image_url'] ?? json['imageUrl'],
    );
    final voiceNote = extractVoiceNote(
      content,
      rawUrl: json['voice_note_url'] as String? ?? json['voiceNoteUrl'] as String?,
      rawDuration: (json['voice_note_duration_seconds'] as num?)?.toInt() ??
          (json['voiceNoteDurationSeconds'] as num?)?.toInt(),
    );

    return ForumReplyModel(
      id: json['id'] as String,
      postId: json['post_id'] as String? ?? '',
      parentReplyId: json['parent_reply_id'] as String? ??
          json['parentReplyId'] as String?,
      authorId: json['author_id'] as String? ?? '',
      authorName: json['author_name'] as String? ?? 'Peer',
      authorAvatar: json['author_avatar'] as String?,
      content: content,
      latexContent: json['latex_content'] as String?,
      isVerifiedSolution: json['is_verified_solution'] as bool? ?? false,
      upvotes: (json['upvotes'] as num?)?.toInt() ?? 0,
      downvotes: (json['downvotes'] as num?)?.toInt() ?? 0,
      userVote: (json['user_vote'] as num?)?.toInt() ??
          (json['userVote'] as num?)?.toInt() ??
          0,
      repliesCount: (json['replies_count'] as num?)?.toInt() ??
          (json['repliesCount'] as num?)?.toInt() ??
          (json['reply_count'] as num?)?.toInt() ??
          (json['replyCount'] as num?)?.toInt() ??
          0,
      mediaUrls: parsedMedia,
      voiceNoteUrl: voiceNote.url,
      voiceNoteDurationSeconds: voiceNote.duration,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'parent_reply_id': parentReplyId,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'content': content,
      'latex_content': latexContent,
      'is_verified_solution': isVerifiedSolution,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'user_vote': userVote,
      'replies_count': repliesCount,
      'media_urls': mediaUrls,
      if (voiceNoteUrl != null) 'voice_note_url': voiceNoteUrl,
      if (voiceNoteDurationSeconds != null)
        'voice_note_duration_seconds': voiceNoteDurationSeconds,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ForumReplyModel copyWith({
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
    int? repliesCount,
    List<String>? mediaUrls,
    String? voiceNoteUrl,
    int? voiceNoteDurationSeconds,
    DateTime? createdAt,
  }) {
    return ForumReplyModel(
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
      repliesCount: repliesCount ?? this.repliesCount,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      voiceNoteUrl: voiceNoteUrl ?? this.voiceNoteUrl,
      voiceNoteDurationSeconds:
          voiceNoteDurationSeconds ?? this.voiceNoteDurationSeconds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  ForumReplyEntity toEntity() {
    return ForumReplyEntity(
      id: id,
      postId: postId,
      parentReplyId: parentReplyId,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      latexContent: latexContent,
      isVerifiedSolution: isVerifiedSolution,
      upvotes: upvotes,
      downvotes: downvotes,
      userVote: userVote,
      repliesCount: repliesCount,
      mediaUrls: mediaUrls,
      voiceNoteUrl: voiceNoteUrl,
      voiceNoteDurationSeconds: voiceNoteDurationSeconds,
      createdAt: createdAt,
    );
  }

  factory ForumReplyModel.fromEntity(ForumReplyEntity entity) {
    return ForumReplyModel(
      id: entity.id,
      postId: entity.postId,
      parentReplyId: entity.parentReplyId,
      authorId: entity.authorId,
      authorName: entity.authorName,
      authorAvatar: entity.authorAvatar,
      content: entity.content,
      latexContent: entity.latexContent,
      isVerifiedSolution: entity.isVerifiedSolution,
      upvotes: entity.upvotes,
      downvotes: entity.downvotes,
      userVote: entity.userVote,
      repliesCount: entity.repliesCount,
      mediaUrls: entity.mediaUrls,
      voiceNoteUrl: entity.voiceNoteUrl,
      voiceNoteDurationSeconds: entity.voiceNoteDurationSeconds,
      createdAt: entity.createdAt,
    );
  }
}
