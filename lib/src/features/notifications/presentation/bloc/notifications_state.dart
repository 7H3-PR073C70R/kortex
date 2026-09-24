import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';

enum NotificationsStatus { initial, loading, loaded, error }

class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.initial,
    this.notifications = const [],
    this.selectedCategory = NotificationCategory.all,
    this.onlyUnread = false,
    this.errorMessage,
  });

  final NotificationsStatus status;
  final List<NotificationItemEntity> notifications;
  final NotificationCategory selectedCategory;
  final bool onlyUnread;
  final String? errorMessage;

  int get unreadCount => notifications.where((n) => !n.isRead).length;

  List<NotificationItemEntity> get filteredNotifications {
    return notifications.where((n) {
      if (onlyUnread && n.isRead) return false;
      if (selectedCategory == NotificationCategory.all) return true;
      return n.category == selectedCategory;
    }).toList();
  }

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<NotificationItemEntity>? notifications,
    NotificationCategory? selectedCategory,
    bool? onlyUnread,
    String? errorMessage,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      onlyUnread: onlyUnread ?? this.onlyUnread,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        notifications,
        selectedCategory,
        onlyUnread,
        errorMessage,
      ];
}
