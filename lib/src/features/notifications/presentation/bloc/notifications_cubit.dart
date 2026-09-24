import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_state.dart';

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({NotificationService? notificationService})
      : _notificationService = notificationService,
        super(const NotificationsState()) {
    _initSubscription();
    loadNotifications();
  }

  final NotificationService? _notificationService;
  StreamSubscription<dynamic>? _messageSubscription;

  void _initSubscription() {
    try {
      final service = _notificationService ??
          (locator.isRegistered<NotificationService>()
              ? locator<NotificationService>()
              : null);
      if (service != null) {
        _messageSubscription = service.onMessage.listen((remoteMessage) {
          final title = remoteMessage.notification?.title ?? 'Kortex Update';
          final body = remoteMessage.notification?.body ?? '';
          final payload = remoteMessage.data['route']?.toString() ??
              remoteMessage.data['payload']?.toString();

          addNotification(
            NotificationItemEntity(
              id: 'remote_${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              message: body,
              timestamp: DateTime.now(),
              category: _mapCategory(remoteMessage.data['category']?.toString()),
              actionRoute: payload,
            ),
          );
        });
      }
    } on Object catch (_) {}
  }

  NotificationCategory _mapCategory(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'study':
      case 'spaced_repetition':
      case 'flashcard':
        return NotificationCategory.study;
      case 'social':
      case 'community':
      case 'circle':
      case 'forum':
        return NotificationCategory.community;
      case 'streak':
        return NotificationCategory.streak;
      default:
        return NotificationCategory.system;
    }
  }

  void loadNotifications() {
    emit(state.copyWith(status: NotificationsStatus.loading));

    // Initial curated scholarly notifications
    final initialList = <NotificationItemEntity>[
      NotificationItemEntity(
        id: 'notif_1',
        title: 'Review Due: Organic Chemistry & Physics',
        message: '18 FSRS active recall cards are ready for your morning review.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 24)),
        category: NotificationCategory.study,
        actionRoute: '/decks',
      ),
      NotificationItemEntity(
        id: 'notif_2',
        title: 'WAEC Mathematics Study Circle Active',
        message: '3 peers are currently studying Calculus in the Live Focus Room.',
        timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
        category: NotificationCategory.community,
        actionRoute: '/community',
      ),
      NotificationItemEntity(
        id: 'notif_3',
        title: 'Streak Protected! 🔥',
        message: 'You have reached a 7-day study streak. Keep up the high retention rate!',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        category: NotificationCategory.streak,
        isRead: true,
        actionRoute: '/dashboard',
      ),
      NotificationItemEntity(
        id: 'notif_4',
        title: 'Exam Timetable Updated',
        message: 'Your JAMB preparatory countdown has been updated with new high-yield topics.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        category: NotificationCategory.system,
        isRead: true,
        actionRoute: '/planner',
      ),
    ];

    emit(
      state.copyWith(
        status: NotificationsStatus.loaded,
        notifications: initialList,
      ),
    );
  }

  void addNotification(NotificationItemEntity notification) {
    final updated = [notification, ...state.notifications];
    emit(state.copyWith(notifications: updated));
  }

  void markAsRead(String id) {
    final updated = state.notifications.map((n) {
      if (n.id == id) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();
    emit(state.copyWith(notifications: updated));
  }

  void markAllAsRead() {
    final updated = state.notifications.map((n) => n.copyWith(isRead: true)).toList();
    emit(state.copyWith(notifications: updated));
  }

  void deleteNotification(String id) {
    final updated = state.notifications.where((n) => n.id != id).toList();
    emit(state.copyWith(notifications: updated));
  }

  void clearAll() {
    emit(state.copyWith(notifications: []));
  }

  void filterByCategory(NotificationCategory category) {
    emit(state.copyWith(selectedCategory: category));
  }

  void toggleOnlyUnread() {
    emit(state.copyWith(onlyUnread: !state.onlyUnread));
  }

  @override
  Future<void> close() async {
    await _messageSubscription?.cancel();
    return super.close();
  }
}
