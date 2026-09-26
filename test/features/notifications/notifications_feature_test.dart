import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/features/notifications/domain/entities/notification_item_entity.dart';
import 'package:kortex/src/features/notifications/domain/services/notification_router.dart';
import 'package:kortex/src/features/notifications/domain/services/smart_study_reminder_scheduler.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}
class MockStackRouter extends Mock implements StackRouter {}
class FakePageRouteInfo extends Fake implements PageRouteInfo<dynamic> {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakePageRouteInfo());
  });

  group('Notifications Feature Test Suite', () {
    test('NotificationCategoryExtension maps string to correct category', () {
      expect(
        NotificationCategoryExtension.fromString('spaced_repetition'),
        equals(NotificationCategory.study),
      );
      expect(
        NotificationCategoryExtension.fromString('quiz_duel_challenge'),
        equals(NotificationCategory.community),
      );
      expect(
        NotificationCategoryExtension.fromString('daily_streak_reminder'),
        equals(NotificationCategory.streak),
      );
      expect(
        NotificationCategoryExtension.fromString('exam_countdown'),
        equals(NotificationCategory.system),
      );
    });

    test('NotificationItemEntity fromJson and toJson roundtrip', () {
      final json = {
        'id': 'notif-101',
        'title': 'Streak Danger!',
        'body': 'Your 15-day streak is ending in 2 hours.',
        'category': 'streak',
        'read': false,
        'action_route': '/planner',
        'created_at': '2026-09-26T20:00:00.000Z',
      };

      final entity = NotificationItemEntity.fromJson(json);
      expect(entity.id, equals('notif-101'));
      expect(entity.title, equals('Streak Danger!'));
      expect(entity.category, equals(NotificationCategory.streak));
      expect(entity.isRead, isFalse);
      expect(entity.actionRoute, equals('/planner'));

      final encoded = entity.toJson();
      expect(encoded['id'], equals('notif-101'));
      expect(encoded['category'], equals('streak'));
    });

    test('SmartStudyReminderScheduler calculates default peak hour when empty', () {
      final mockStorage = MockLocalStorageService();
      when(() => mockStorage.getPreference(key: 'study_session_history'))
          .thenReturn(null);

      final scheduler = SmartStudyReminderScheduler(localStorageService: mockStorage);
      expect(scheduler.calculateOptimalRetentionHour(), equals(19));
      expect(scheduler.calculateNextReminderSchedule().hour, equals(19));
    });

    test('SmartStudyReminderScheduler identifies peak hour from study history', () {
      final mockStorage = MockLocalStorageService();
      final timestamps = [
        '2026-09-26T14:15:00.000Z',
        '2026-09-25T14:30:00.000Z',
        '2026-09-24T14:45:00.000Z',
        '2026-09-23T20:00:00.000Z',
      ].join(',');

      when(() => mockStorage.getPreference(key: 'study_session_history'))
          .thenReturn(timestamps);

      final scheduler = SmartStudyReminderScheduler(localStorageService: mockStorage);
      expect(scheduler.calculateOptimalRetentionHour(), equals(14));
    });

    test('NotificationRouter parses quiz duel payload correctly', () async {
      final mockRouter = MockStackRouter();
      when(() => mockRouter.push(any())).thenAnswer((_) async => null);

      const router = NotificationRouter();
      final notif = NotificationItemEntity(
        id: 'n-duel',
        title: '1v1 Duel Challenge',
        message: 'Alex challenged you to a CBT Duel!',
        timestamp: DateTime.now(),
        category: NotificationCategory.community,
        actionRoute: 'quiz_duel',
        metadata: const {'type': 'quiz_duel', 'duel_id': 'duel-999'},
      );

      final routed = await router.handleNotificationNavigation(
        router: mockRouter,
        notification: notif,
      );

      expect(routed, isTrue);
      verify(() => mockRouter.push(any())).called(1);
    });
  });
}
