import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_state.dart';

void main() {
  group('NotificationsCubit and Entity Test Suite', () {
    test('NotificationItemEntity serialization and copyWith work properly', () {
      final notif = NotificationItemEntity(
        id: 'notif_abc',
        title: 'Study Reminder',
        message: 'Review due for Calculus',
        timestamp: DateTime(2026, 9, 24, 10),
        category: NotificationCategory.study,
        actionRoute: '/decks',
      );

      expect(notif.isRead, isFalse);

      final json = notif.toJson();
      expect(json['id'], equals('notif_abc'));
      expect(json['title'], equals('Study Reminder'));
      expect(json['category'], equals('study'));

      final parsed = NotificationItemEntity.fromJson(json);
      expect(parsed.id, equals(notif.id));
      expect(parsed.title, equals(notif.title));
      expect(parsed.message, equals(notif.message));
      expect(parsed.category, equals(NotificationCategory.study));
      expect(parsed.actionRoute, equals('/decks'));

      final updated = notif.copyWith(isRead: true, category: NotificationCategory.streak);
      expect(updated.isRead, isTrue);
      expect(updated.category, equals(NotificationCategory.streak));
      expect(updated.id, equals('notif_abc'));
    });

    test('NotificationsCubit tracks notifications, reads, and unread count', () async {
      final item1 = NotificationItemEntity(
        id: 'notif_1',
        title: 'Welcome',
        message: 'Welcome to Kortex',
        timestamp: DateTime.now(),
        category: NotificationCategory.system,
      );
      final item2 = NotificationItemEntity(
        id: 'notif_2',
        title: 'Review Due',
        message: 'Cards are ready',
        timestamp: DateTime.now(),
        category: NotificationCategory.study,
      );

      final cubit = NotificationsCubit()
        ..addNotification(item1)
        ..addNotification(item2);

      expect(cubit.state.status, equals(NotificationsStatus.loaded));
      expect(cubit.state.notifications.length, equals(2));
      expect(cubit.state.unreadCount, equals(2));

      await cubit.markAsRead('notif_2');
      expect(
        cubit.state.notifications.firstWhere((n) => n.id == 'notif_2').isRead,
        isTrue,
      );
      expect(cubit.state.unreadCount, equals(1));

      await cubit.markAllAsRead();
      expect(cubit.state.unreadCount, equals(0));
      expect(cubit.state.notifications.every((n) => n.isRead), isTrue);

      await cubit.close();
    });

    test('NotificationsCubit filters by category, showAll, and unread status correctly', () async {
      final cubit = NotificationsCubit()
        ..addNotification(
          NotificationItemEntity(
            id: 'n_study',
            title: 'Study',
            message: 'Review due',
            timestamp: DateTime.now(),
            category: NotificationCategory.study,
          ),
        )
        ..addNotification(
          NotificationItemEntity(
            id: 'n_comm',
            title: 'Forum',
            message: 'Reply posted',
            timestamp: DateTime.now(),
            category: NotificationCategory.community,
            isRead: true,
          ),
        )
        ..selectCategory(NotificationCategory.study);

      expect(cubit.state.selectedCategory, equals(NotificationCategory.study));
      expect(cubit.state.onlyUnread, isFalse);
      expect(cubit.state.filteredNotifications.length, equals(1));
      expect(cubit.state.filteredNotifications.first.category, equals(NotificationCategory.study));

      cubit.toggleOnlyUnread();
      expect(cubit.state.onlyUnread, isTrue);

      cubit.showAll();
      expect(cubit.state.selectedCategory, equals(NotificationCategory.all));
      expect(cubit.state.onlyUnread, isFalse);
      expect(cubit.state.filteredNotifications.length, equals(2));

      await cubit.close();
    });

    test('NotificationsCubit adds and deletes notifications', () async {
      final cubit = NotificationsCubit();
      final initialCount = cubit.state.notifications.length;

      final newNotif = NotificationItemEntity(
        id: 'custom_99',
        title: 'New Quiz Duel Challenge',
        message: 'Player Alex challenged you',
        timestamp: DateTime.now(),
        category: NotificationCategory.community,
      );

      cubit.addNotification(newNotif);
      expect(cubit.state.notifications.length, equals(initialCount + 1));
      expect(cubit.state.notifications.first.id, equals('custom_99'));

      await cubit.deleteNotification('custom_99');
      expect(cubit.state.notifications.length, equals(initialCount));

      cubit.clearAll();
      expect(cubit.state.notifications.isEmpty, isTrue);

      await cubit.close();
    });
  });
}
