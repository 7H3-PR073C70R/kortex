import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

void main() {
  late MockLocalStorageService mockLocalStorageService;
  late UserActivityServiceImpl userActivityService;
  final storageMap = <String, String>{};

  setUp(() {
    storageMap.clear();
    mockLocalStorageService = MockLocalStorageService();

    when(() => mockLocalStorageService.getPreference(key: any(named: 'key')))
        .thenAnswer((invocation) {
      final key = invocation.namedArguments[#key] as String;
      return storageMap[key];
    });

    when(
      () => mockLocalStorageService.savePreference(
        key: any(named: 'key'),
        data: any(named: 'data'),
      ),
    ).thenAnswer((invocation) async {
      final key = invocation.namedArguments[#key] as String;
      final data = invocation.namedArguments[#data] as String;
      storageMap[key] = data;
    });

    userActivityService = UserActivityServiceImpl(mockLocalStorageService);
  });

  group('UserActivityService XP & Gamification Engine Tests', () {
    test('streak multiplier returns 1.0x for 0-3 day streak', () {
      expect(userActivityService.getStreakMultiplier(), equals(1.0));
    });

    test('streak multiplier scales dynamically with streak days', () async {
      // 4 days -> 1.25x
      storageMap['__kortex_streak_current'] = '4';
      expect(userActivityService.getStreakMultiplier(), equals(1.25));

      // 7 days -> 1.5x
      storageMap['__kortex_streak_current'] = '7';
      expect(userActivityService.getStreakMultiplier(), equals(1.5));

      // 14 days -> 1.75x
      storageMap['__kortex_streak_current'] = '14';
      expect(userActivityService.getStreakMultiplier(), equals(1.75));

      // 30 days -> 2.0x
      storageMap['__kortex_streak_current'] = '30';
      expect(userActivityService.getStreakMultiplier(), equals(2.0));
    });

    test('awardXp calculates base XP, streak multiplier, and updates totals',
        () async {
      storageMap['__kortex_streak_current'] = '7'; // 1.5x multiplier

      final event = await userActivityService.awardXp(
        XpActivityCategory.quizCompletion,
        sourceId: 'quiz_123',
        metadata: {'score': 90},
      );

      // Base 100 * 1.5 = 150
      expect(event.category, equals(XpActivityCategory.quizCompletion));
      expect(event.baseAmount, equals(100));
      expect(event.multiplier, equals(1.5));
      expect(event.xpEarned, equals(150));
      expect(event.totalXp, equals(360));
      expect(event.sourceId, equals('quiz_123'));
    });

    test('awardXp emits telemetry events onto xpEarnedStream', () async {
      final events = <XpEarnedEvent>[];
      final sub = userActivityService.xpEarnedStream.listen(events.add);

      await userActivityService.awardXp(XpActivityCategory.syllabotQuery);
      await userActivityService.awardXp(XpActivityCategory.communityPost);

      await Future<void>.delayed(Duration.zero);
      expect(events.length, equals(2));
      expect(events[0].category, equals(XpActivityCategory.syllabotQuery));
      expect(events[1].category, equals(XpActivityCategory.communityPost));

      await sub.cancel();
    });

    test('getXpTransactions returns audit log history', () async {
      await userActivityService.awardXp(
        XpActivityCategory.plannerTaskCompletion,
        sourceId: 'task_001',
      );
      await userActivityService.awardXp(
        XpActivityCategory.focusSession,
        sourceId: 'room_99',
      );

      final txs = userActivityService.getXpTransactions();
      expect(txs.length, equals(2));
      expect(txs[0]['category'], equals('focusSession'));
      expect(txs[1]['category'], equals('plannerTaskCompletion'));
    });

    test('getLevelForXp computes level smoothly along logarithmic curve', () {
      expect(userActivityService.getLevelForXp(0), equals(1));
      expect(userActivityService.getLevelForXp(300), greaterThanOrEqualTo(2));
      expect(userActivityService.getLevelForXp(1500), greaterThanOrEqualTo(5));
      expect(userActivityService.getLevelForXp(4000), greaterThanOrEqualTo(10));
    });

    test('purchaseStreakFreeze deducts spent XP correctly', () async {
      await userActivityService.awardXp(
        XpActivityCategory.quizCompletion,
        customBaseAmount: 300,
      );

      final startXp = userActivityService.getXpPoints();
      expect(startXp, equals(300));

      final success = await userActivityService.purchaseStreakFreeze(costXp: 200);
      expect(success, isTrue);

      final remainingXp = userActivityService.getXpPoints();
      expect(remainingXp, equals(100));
      expect(userActivityService.getStreakFreezes(), equals(2));
    });
  });
}
