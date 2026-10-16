import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_state.dart';
import 'package:kortex/src/features/notifications/presentation/pages/notifications_page.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/mobile_mark_all_read_button.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_empty_view.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_filter_chips.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_header.dart';
import 'package:kortex/src/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../helpers/pump_app.dart';

class MockNotificationsCubit extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

Future<void> withPlatform(TargetPlatform platform, Future<void> Function() fn) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await fn();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(NotificationCategory.all);
  });

  group('NotificationsPage Widget Tests', () {
    late MockNotificationsCubit mockNotificationsCubit;

    final testNotifications = [
      NotificationItemEntity(
        id: 'notif_1',
        title: 'Study Reminder',
        message: 'Time to review your physics flashcards.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        category: NotificationCategory.study,
      ),
      NotificationItemEntity(
        id: 'notif_2',
        title: 'Streak Milestone',
        message: 'You have reached a 7-day study streak!',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        category: NotificationCategory.streak,
        isRead: true,
      ),
    ];

    setUp(() {
      mockNotificationsCubit = MockNotificationsCubit();
      when(() => mockNotificationsCubit.markAsRead(any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationsCubit.markAllAsRead())
          .thenAnswer((_) async {});
      when(() => mockNotificationsCubit.deleteNotification(any()))
          .thenAnswer((_) async {});
      when(() => mockNotificationsCubit.selectCategory(any()))
          .thenReturn(null);
      when(() => mockNotificationsCubit.toggleOnlyUnread())
          .thenReturn(null);
      when(() => mockNotificationsCubit.showAll())
          .thenReturn(null);
      when(() => mockNotificationsCubit.loadNotifications(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async {});
    });

    testWidgets('renders empty view when notifications list is empty', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockNotificationsCubit.state).thenReturn(
          const NotificationsState(
            status: NotificationsStatus.loaded,
          ),
        );

        await tester.pumpApp(
          NotificationsPage(notificationsCubit: mockNotificationsCubit),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Notifications'), findsWidgets);
        expect(find.byType(NotificationFilterChips), findsOneWidget);
        expect(find.byType(NotificationEmptyView), findsOneWidget);
        expect(find.text('No Notifications'), findsOneWidget);
      });
    });

    testWidgets('renders notification tiles and filter chips when items exist', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockNotificationsCubit.state).thenReturn(
          NotificationsState(
            status: NotificationsStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await tester.pumpApp(
          NotificationsPage(notificationsCubit: mockNotificationsCubit),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(NotificationTile), findsNWidgets(2));
        expect(find.text('Study Reminder'), findsOneWidget);
        expect(find.text('Streak Milestone'), findsOneWidget);
        expect(find.byType(MobileMarkAllReadButton), findsOneWidget);
      });
    });

    testWidgets('triggers markAllAsRead when mobile mark all read button is tapped', (tester) async {
      await withPlatform(TargetPlatform.android, () async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockNotificationsCubit.state).thenReturn(
          NotificationsState(
            status: NotificationsStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await tester.pumpApp(
          NotificationsPage(notificationsCubit: mockNotificationsCubit),
        );
        await tester.pump(const Duration(milliseconds: 500));

        final markAllReadFinder = find.byType(MobileMarkAllReadButton);
        expect(markAllReadFinder, findsOneWidget);

        await tester.tap(markAllReadFinder);
        await tester.pump(const Duration(milliseconds: 500));

        verify(() => mockNotificationsCubit.markAllAsRead()).called(1);
      });
    });

    testWidgets('renders desktop drawer panel in drawer mode', (tester) async {
      await withPlatform(TargetPlatform.macOS, () async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(() => mockNotificationsCubit.state).thenReturn(
          NotificationsState(
            status: NotificationsStatus.loaded,
            notifications: testNotifications,
          ),
        );

        await tester.pumpApp(
          NotificationsPage(
            isDrawer: true,
            notificationsCubit: mockNotificationsCubit,
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(DesktopNotificationDrawerPanel), findsOneWidget);
        expect(find.byType(NotificationHeader), findsOneWidget);
      });
    });
  });
}
