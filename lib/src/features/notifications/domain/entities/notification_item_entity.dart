import 'package:equatable/equatable.dart';

/// Categories of notifications in Kortex.
enum NotificationCategory {
  all,
  study,
  community,
  streak,
  system,
}

extension NotificationCategoryExtension on NotificationCategory {
  static NotificationCategory fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'study':
      case 'spaced_repetition':
      case 'memory_decay':
      case 'ai_ingestion':
      case 'flashcard':
      case 'review_due':
        return NotificationCategory.study;
      case 'social':
      case 'community':
      case 'circle':
      case 'forum':
      case 'room_invite':
      case 'deck_cloned':
      case 'leaderboard':
      case 'quiz_duel_challenge':
      case 'quiz_duel_result':
        return NotificationCategory.community;
      case 'streak':
      case 'streak_protection':
      case 'streak_milestone':
      case 'daily_streak_reminder':
        return NotificationCategory.streak;
      case 'exam_countdown':
      case 'exam_milestones':
      case 'exam':
      case 'planner':
      case 'system':
      case 'security':
      case 'general':
      case 'welcome':
      default:
        return NotificationCategory.system;
    }
  }
}

/// Represents an individual notification in Kortex.
class NotificationItemEntity extends Equatable {
  const NotificationItemEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isRead = false,
    this.actionRoute,
    this.metadata,
  });

  factory NotificationItemEntity.fromJson(Map<String, dynamic> json) {
    final rawCategory = json['category']?.toString();
    final rawData = json['data'];
    final metadata = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : null);

    final actionRoute = json['actionRoute']?.toString() ??
        json['action_route']?.toString() ??
        metadata?['route']?.toString() ??
        metadata?['actionRoute']?.toString() ??
        metadata?['payload']?.toString();

    final timestampStr = json['created_at']?.toString() ??
        json['timestamp']?.toString() ??
        json['createdAt']?.toString();
    final timestamp = timestampStr != null
        ? (DateTime.tryParse(timestampStr) ?? DateTime.now())
        : DateTime.now();

    final isRead = json['read'] == true ||
        json['is_read'] == true ||
        json['isRead'] == true;

    return NotificationItemEntity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['body']?.toString() ??
          json['message']?.toString() ??
          '',
      timestamp: timestamp,
      category: NotificationCategoryExtension.fromString(rawCategory),
      isRead: isRead,
      actionRoute: actionRoute,
      metadata: metadata,
    );
  }

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic>? metadata;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': message,
      'message': message,
      'category': category.name,
      'read': isRead,
      'is_read': isRead,
      'created_at': timestamp.toIso8601String(),
      'action_route': actionRoute,
      if (metadata != null || actionRoute != null)
        'data': metadata ?? (actionRoute != null ? {'route': actionRoute} : {}),
    };
  }

  NotificationItemEntity copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationCategory? category,
    bool? isRead,
    String? actionRoute,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItemEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      category: category ?? this.category,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        message,
        timestamp,
        category,
        isRead,
        actionRoute,
        metadata,
      ];
}
