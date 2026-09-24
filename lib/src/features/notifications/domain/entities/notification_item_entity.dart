import 'package:equatable/equatable.dart';

/// Categories of notifications in Kortex.
enum NotificationCategory {
  all,
  study,
  community,
  streak,
  system,
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

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationCategory category;
  final bool isRead;
  final String? actionRoute;
  final Map<String, dynamic>? metadata;

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
