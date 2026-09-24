import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_state.dart';

void main() {
  group('NotificationsCubit and Entity Test Suite', () {
    test('NotificationItemEntity copyWith updates values properly', () {
      final notif = NotificationItemEntity(
        id: '1',
        title: 'Study Reminder',
        message: 'Review due',
        timestamp: DateTime(2026, 9, 24),
        category: NotificationCategory.study,
      );

      expect(notif.isRead, isFalse);

      final updated = notif.copyWith(isRead: true, category: NotificationCategory.streak);
      expect(updated.isRead, isTrue);
      expect(updated.category, equals(NotificationCategory.streak));
      expect(updated.id, equals('1'));
    });

    test('NotificationsCubit loads initial notifications and tracks unread count', () {
      final cubit = NotificationsCubit();

      expect(cubit.state.status, equals(NotificationsStatus.loaded));
      expect(cubit.state.notifications.isNotEmpty, isTrue);
      expect(cubit.state.unreadCount, greaterThan(0));

      final firstUnread = cubit.state.notifications.firstWhere((n) => !n.isRead);
      cubit.markAsRead(firstUnread.id);
      expect(
        cubit.state.notifications.firstWhere((n) => n.id == firstUnread.id).isRead,
        isTrue,
      );

      cubit.markAllAsRead();
      expect(cubit.state.unreadCount, equals(0));
      expect(cubit.state.notifications.every((n) => n.isRead), isTrue);

      unawaited(cubit.close());
    });

    test('NotificationsCubit filters by category and unread status correctly', () {
      final cubit = NotificationsCubit()

      ..filterByCategory(NotificationCategory.study);
      expect(cubit.state.selectedCategory, equals(NotificationCategory.study));
      expect(
        cubit.state.filteredNotifications.every(
          (n) => n.category == NotificationCategory.study,
        ),
        isTrue,
      );

      cubit..filterByCategory(NotificationCategory.all)
      ..toggleOnlyUnread();
      expect(cubit.state.onlyUnread, isTrue);
      expect(
        cubit.state.filteredNotifications.every((n) => !n.isRead),
        isTrue,
      );

      unawaited(cubit.close());
    });

    test('NotificationsCubit adds and deletes notifications', () {
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

      cubit.deleteNotification('custom_99');
      expect(cubit.state.notifications.length, equals(initialCount));

      cubit.clearAll();
      expect(cubit.state.notifications.isEmpty, isTrue);

      unawaited(cubit.close());
    });
  });
}
