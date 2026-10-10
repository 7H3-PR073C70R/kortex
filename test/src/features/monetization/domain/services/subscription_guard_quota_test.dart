import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:mocktail/mocktail.dart';

class MockUserStorageService extends Mock implements UserStorageService {}
class MockIngestionRemoteDataSource extends Mock implements IngestionRemoteDataSource {}
class MockSyllabotRemoteDataSource extends Mock implements SyllabotRemoteDataSource {}

void main() {
  late MockUserStorageService mockUserStorage;
  late MockIngestionRemoteDataSource mockRemoteDataSource;
  late MockSyllabotRemoteDataSource mockSyllabotRemoteDataSource;
  late SubscriptionGuard guard;

  setUp(() {
    mockUserStorage = MockUserStorageService();
    mockRemoteDataSource = MockIngestionRemoteDataSource();
    mockSyllabotRemoteDataSource = MockSyllabotRemoteDataSource();

    guard = SubscriptionGuard(
      userStorageService: mockUserStorage,
      ingestionRemoteDataSource: mockRemoteDataSource,
      syllabotRemoteDataSource: mockSyllabotRemoteDataSource,
    );
  });

  group('SubscriptionGuard - DB-Backed Quotas & Unlimited Local Synthesis', () {
    test('Local synthesis has NO CAP for free users', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);

      expect(guard.isPro, isFalse);
      expect(guard.canUseLocalSynthesis(), isTrue);
      expect(
        guard.canSynthesizeDocument(
          fileSizeBytes: 10 * 1024 * 1024,
          isFastLocal: true,
        ),
        isTrue,
      );
    });

    test('Local synthesis has NO CAP for Pro users', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);

      expect(guard.isPro, isTrue);
      expect(guard.canUseLocalSynthesis(), isTrue);
      expect(
        guard.canSynthesizeDocument(
          fileSizeBytes: 50 * 1024 * 1024,
          isFastLocal: true,
        ),
        isTrue,
      );
    });

    test('Free users cannot use AI Smart Gen (gated behind Pro)', () {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);

      expect(guard.canUseAiSmartGen(), isFalse);
      expect(guard.getRemainingAiSmartGenCount(), equals(0));
      expect(
        guard.canSynthesizeDocument(
          fileSizeBytes: 10 * 1024 * 1024,
          isFastLocal: false,
        ),
        isFalse,
      );
    });

    test('Pro users query DB quota and can use AI Smart Gen up to 30 requests/day', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      when(() => mockRemoteDataSource.getAiSmartGenQuota()).thenAnswer(
        (_) async => {
          'is_pro': true,
          'today_count': 10,
          'limit': 30,
          'remaining': 20,
          'can_use': true,
        },
      );

      final quota = await guard.fetchAiSmartGenQuota();

      expect(quota['is_pro'], isTrue);
      expect(guard.getTodayAiSmartGenCount(), equals(10));
      expect(guard.getRemainingAiSmartGenCount(), equals(20));
      expect(guard.canUseAiSmartGen(), isTrue);
      verify(() => mockRemoteDataSource.getAiSmartGenQuota()).called(1);
    });

    test('Pro users are capped when daily AI Smart Gen count reaches 30', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      when(() => mockRemoteDataSource.getAiSmartGenQuota()).thenAnswer(
        (_) async => {
          'is_pro': true,
          'today_count': 30,
          'limit': 30,
          'remaining': 0,
          'can_use': false,
        },
      );

      await guard.fetchAiSmartGenQuota();

      expect(guard.getTodayAiSmartGenCount(), equals(30));
      expect(guard.getRemainingAiSmartGenCount(), equals(0));
      expect(guard.canUseAiSmartGen(), isFalse);

      // Even when capped on AI Smart Gen, Local Synthesis is STILL 100% UNLIMITED!
      expect(guard.canUseLocalSynthesis(), isTrue);
      expect(
        guard.canSynthesizeDocument(
          fileSizeBytes: 20 * 1024 * 1024,
          isFastLocal: true,
        ),
        isTrue,
      );
    });

    test('recordAiSmartGenUsage calls DB RPC and increments quota count', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      when(() => mockRemoteDataSource.recordAiSmartGenUsage()).thenAnswer(
        (_) async => {
          'success': true,
          'today_count': 15,
          'limit': 30,
          'remaining': 15,
        },
      );

      await guard.recordAiSmartGenUsage();

      expect(guard.getTodayAiSmartGenCount(), equals(15));
      expect(guard.getRemainingAiSmartGenCount(), equals(15));
      verify(() => mockRemoteDataSource.recordAiSmartGenUsage()).called(1);
    });
  });

  group('SubscriptionGuard - Server-Authoritative Syllabot Tracking & Counts', () {
    test('On-Device AI queries are unlimited for all users with zero server tracking', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);

      expect(guard.canQuerySyllabot(engineType: ExecutionEngineType.localOnDevice), isTrue);
      await guard.recordSyllabotQuery(engineType: ExecutionEngineType.localOnDevice);

      expect(guard.getTodaySyllabotQueryCount(), equals(0));
      verifyNever(() => mockSyllabotRemoteDataSource.recordSyllabotUsage(tokenCount: any(named: 'tokenCount')));
    });

    test('Free users query server DB for Syllabot quota and track queries up to 20/day', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);
      when(() => mockSyllabotRemoteDataSource.getSyllabotQuota()).thenAnswer(
        (_) async => {
          'is_pro': false,
          'today_count': 5,
          'limit': 20,
          'remaining': 15,
          'can_use': true,
        },
      );

      final quota = await guard.fetchSyllabotQuota();

      expect(quota['is_pro'], isFalse);
      expect(guard.getTodaySyllabotQueryCount(), equals(5));
      expect(guard.canQuerySyllabot(), isTrue);
      verify(() => mockSyllabotRemoteDataSource.getSyllabotQuota()).called(1);
    });

    test('Free users are gated from Cloud Syllabot when server count reaches 20', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(false);
      when(() => mockSyllabotRemoteDataSource.getSyllabotQuota()).thenAnswer(
        (_) async => {
          'is_pro': false,
          'today_count': 20,
          'limit': 20,
          'remaining': 0,
          'can_use': false,
        },
      );

      await guard.fetchSyllabotQuota();

      expect(guard.getTodaySyllabotQueryCount(), equals(20));
      expect(guard.canQuerySyllabot(), isFalse);

      // Local engine remains completely UNLIMITED even when cloud is exhausted!
      expect(guard.canQuerySyllabot(engineType: ExecutionEngineType.localOnDevice), isTrue);
    });

    test('Pro users have their Syllabot usage and count tracked on the server with unlimited access', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      when(() => mockSyllabotRemoteDataSource.getSyllabotQuota()).thenAnswer(
        (_) async => {
          'is_pro': true,
          'today_count': 42,
          'limit': null,
          'remaining': null,
          'can_use': true,
        },
      );

      final quota = await guard.fetchSyllabotQuota();

      expect(quota['is_pro'], isTrue);
      expect(guard.getTodaySyllabotQueryCount(), equals(42));
      expect(guard.canQuerySyllabot(), isTrue);
      verify(() => mockSyllabotRemoteDataSource.getSyllabotQuota()).called(1);
    });

    test('recordSyllabotQuery sends usage to server DB via RPC and updates count', () async {
      when(() => mockUserStorage.isProSubscriber()).thenReturn(true);
      when(() => mockSyllabotRemoteDataSource.recordSyllabotUsage()).thenAnswer(
        (_) async => {
          'is_pro': true,
          'today_count': 43,
          'limit': null,
          'remaining': null,
          'can_use': true,
        },
      );

      await guard.recordSyllabotQuery();

      expect(guard.getTodaySyllabotQueryCount(), equals(43));
      verify(() => mockSyllabotRemoteDataSource.recordSyllabotUsage()).called(1);
    });
  });
}
