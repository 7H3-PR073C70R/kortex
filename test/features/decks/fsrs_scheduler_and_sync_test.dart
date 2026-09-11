import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockDio extends Mock implements Dio {}

class _FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> _store = {};

  @override
  Future<void> initDB() async {}

  @override
  String? getPreference({required String key}) => _store[key];

  @override
  Future<void> savePreference({
    required String key,
    required String data,
  }) async {
    _store[key] = data;
  }

  @override
  Future<void> deletePreference({required String key}) async {
    _store.remove(key);
  }
}

class _FakeUserStorageService implements UserStorageService {
  String? token;
  String? refreshToken;
  bool isPro = false;

  @override
  Future<void> initStorage() async {}

  @override
  bool isTokenExpired() => false;

  @override
  String? getToken() => token;

  @override
  String? getRefreshToken() => refreshToken;

  @override
  Future<void> saveToken(String token) async => this.token = token;

  @override
  Future<void> saveRefreshToken(String refreshToken) async =>
      this.refreshToken = refreshToken;

  @override
  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    token = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  String? getUserId() => 'user_123';

  @override
  String? getUserDisplayName() => 'Scholar Adeola';

  @override
  String? getUserAvatarUrl() => null;

  @override
  String? getUserEmail() => 'scholar@kortex.app';

  @override
  Future<void> saveUserEmail(String email) async {}

  @override
  Future<void> saveUserDisplayName(String displayName) async {}

  @override
  Future<void> saveUserAvatarUrl(String avatarUrl) async {}

  @override
  Future<void> saveProStatus({required bool isPro}) async => this.isPro = isPro;

  @override
  bool isProSubscriber() => isPro;

  @override
  void clearStorage() {
    token = null;
    refreshToken = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FsrsScheduler Algorithm & Review Cycle Test Suite', () {
    late FsrsScheduler scheduler;

    setUp(() {
      scheduler = FsrsScheduler();
    });

    test('Review generates UTC timestamps and unique transaction UUIDs', () {
      const initialCard = FsrsCard(cardId: 'card_math_101');
      const customTxUuid = 'e8b7c4d2-1234-4567-89ab-cdef01234567';

      final review = scheduler.reviewCard(
        currentCard: initialCard,
        rating: FsrsRating.good,
        now: DateTime.utc(2026, 8, 31, 12),
        transactionUuid: customTxUuid,
      );

      expect(review.card.reps, equals(1));
      expect(review.card.lastReviewedEpoch, equals(1788177600000));
      expect(review.log.transactionUuid, equals(customTxUuid));
      expect(review.log.reviewedAtUtc.isUtc, isTrue);

      final payload = review.log.toSupabasePayload();
      expect(payload['transaction_uuid'], equals(customTxUuid));
      expect(payload['rating'], equals(3));
      expect(payload['stability'], equals(review.card.stability));
    });

    test(
      'First review computes stability and difficulty properly for ratings',
      () {
        const initialCard = FsrsCard(cardId: 'card_math_101');

        final goodReview = scheduler.reviewCard(
          currentCard: initialCard,
          rating: FsrsRating.good,
          now: DateTime.utc(2026, 8, 31, 12),
        );

        expect(goodReview.card.reps, equals(1));
        expect(goodReview.card.lapses, equals(0));
        expect(goodReview.card.state, equals(FsrsCardState.review));
        expect(goodReview.card.stability, greaterThan(0));
        expect(goodReview.card.difficulty, inInclusiveRange(1.0, 10.0));
        expect(goodReview.card.scheduledDays, greaterThanOrEqualTo(1));
        expect(goodReview.card.due, isNotNull);

        // Lapse review (Again rating)
        final againReview = scheduler.reviewCard(
          currentCard: initialCard,
          rating: FsrsRating.again,
          now: DateTime.utc(2026, 8, 31, 12),
        );

        expect(againReview.card.reps, equals(1));
        expect(againReview.card.lapses, equals(1));
        expect(againReview.card.state, equals(FsrsCardState.learning));
      },
    );

    test('Retrievability decays over elapsed time', () {
      const stability = 10.0;
      final rDay0 = scheduler.retrievability(0, stability);
      final rDay5 = scheduler.retrievability(5, stability);
      final rDay20 = scheduler.retrievability(20, stability);

      expect(rDay0, equals(1.0));
      expect(rDay5, lessThan(rDay0));
      expect(rDay20, lessThan(rDay5));
      expect(rDay20, greaterThan(0.0));
    });

    test('SQLite serialization toMap and fromMap roundtrip', () {
      final card = FsrsCard(
        cardId: 'card_123',
        due: DateTime.utc(2026, 9, 5, 10, 30),
        stability: 4.5,
        difficulty: 5.2,
        elapsedDays: 3,
        scheduledDays: 5,
        reps: 2,
        state: FsrsCardState.review,
        lastReview: DateTime.utc(2026, 8, 31, 10, 30),
        lastReviewedEpoch: 1788172200000,
      );

      final map = card.toMap();
      final reconstructed = FsrsCard.fromMap(map);

      expect(reconstructed.cardId, equals(card.cardId));
      expect(reconstructed.stability, equals(card.stability));
      expect(reconstructed.difficulty, equals(card.difficulty));
      expect(reconstructed.lastReviewedEpoch, equals(card.lastReviewedEpoch));
      expect(reconstructed.state, equals(card.state));
    });
  });

  group('CardSyncQueue Local-First Sync Suite', () {
    late MockConnectivity mockConnectivity;
    late StreamController<List<ConnectivityResult>> connectivityController;

    setUp(() {
      mockConnectivity = MockConnectivity();
      connectivityController =
          StreamController<List<ConnectivityResult>>.broadcast();
      when(
        () => mockConnectivity.onConnectivityChanged,
      ).thenAnswer((_) => connectivityController.stream);
    });

    tearDown(() async {
      await connectivityController.close();
    });

    test('Buffers review logs with UUIDs and manages pending count', () async {
      final queue = CardSyncQueue(connectivity: mockConnectivity);

      final log1 = FsrsReviewLog(
        id: 'log_1',
        transactionUuid: 'tx_uuid_1',
        cardId: 'card_1',
        rating: FsrsRating.good,
        stability: 2.5,
        difficulty: 4.8,
        elapsedDays: 1,
        scheduledDays: 3,
        reviewedAtUtc: DateTime.now().toUtc(),
        reviewedAtEpoch: DateTime.now().millisecondsSinceEpoch,
        state: FsrsCardState.review,
      );

      final log2 = FsrsReviewLog(
        id: 'log_2',
        transactionUuid: 'tx_uuid_2',
        cardId: 'card_2',
        rating: FsrsRating.again,
        stability: 0.5,
        difficulty: 6.2,
        elapsedDays: 0,
        scheduledDays: 1,
        reviewedAtUtc: DateTime.now().toUtc(),
        reviewedAtEpoch: DateTime.now().millisecondsSinceEpoch,
        state: FsrsCardState.learning,
      );

      await queue.enqueueReview(log1);
      await queue.enqueueReview(log2);

      expect(queue.getPendingCount(), equals(2));
      await queue.dispose();
    });

    test(
      'Persists queued review logs to LocalStorageService and reloads on startup',
      () async {
        final fakeStorage = _FakeLocalStorageService();
        final queue1 = CardSyncQueue(
          connectivity: mockConnectivity,
          storageService: fakeStorage,
        );

        const persistTxUuid = 'f9c8d5e3-2345-4678-9abc-def012345678';
        final log = FsrsReviewLog(
          id: '1',
          transactionUuid: persistTxUuid,
          cardId: 'card_persist',
          rating: FsrsRating.easy,
          stability: 4,
          difficulty: 3,
          elapsedDays: 2,
          scheduledDays: 7,
          reviewedAtUtc: DateTime.utc(2026, 9, 1, 12),
          reviewedAtEpoch: 1788264000000,
          state: FsrsCardState.review,
        );

        await queue1.enqueueReview(log);
        expect(queue1.getPendingCount(), equals(1));
        await queue1.dispose();

        // Instantiate a second queue instance reading from the same storage
        final queue2 = CardSyncQueue(
          connectivity: mockConnectivity,
          storageService: fakeStorage,
        );

        expect(queue2.getPendingCount(), equals(1));
        final pending = queue2.pendingLogs;
        expect(pending.first.transactionUuid, equals(persistTxUuid));
        expect(pending.first.cardId, equals('card_persist'));
        expect(pending.first.rating, equals(FsrsRating.easy));
        expect(pending.first.stability, equals(4.0));
        await queue2.dispose();
      },
    );

    test(
      'currentAuthToken dynamically resolves from UserStorageService and prevents anon token leak',
      () async {
        final fakeUserStorage = _FakeUserStorageService();
        final queue = CardSyncQueue(
          connectivity: mockConnectivity,
          userStorageService: fakeUserStorage,
        );

        // 1. Unauthenticated: currentAuthToken is null (never falls back to AppEnv.apiKey as Bearer)
        expect(queue.currentAuthToken, isNull);

        // 2. User logs in: token is updated in UserStorageService
        fakeUserStorage.token = 'jwt_scholar_user_token_123';
        expect(queue.currentAuthToken, equals('jwt_scholar_user_token_123'));

        // 3. User logs out: token cleared, returns to null
        fakeUserStorage.clearStorage();
        expect(queue.currentAuthToken, isNull);

        await queue.dispose();
      },
    );

    test(
      'flushPendingLogs postpones sync and keeps logs buffered safely when unauthenticated',
      () async {
        final mockDio = MockDio();
        final fakeStorage = _FakeLocalStorageService();
        final fakeUserStorage = _FakeUserStorageService(); // unauthenticated (token null)

        final queue = CardSyncQueue(
          dio: mockDio,
          connectivity: mockConnectivity,
          storageService: fakeStorage,
          userStorageService: fakeUserStorage,
        );

        final log = FsrsReviewLog(
          id: '1',
          transactionUuid: 'uuid-unauth-1',
          cardId: 'card-unauth-1',
          rating: FsrsRating.good,
          stability: 2.5,
          difficulty: 4.8,
          elapsedDays: 1,
          scheduledDays: 3,
          reviewedAtUtc: DateTime.now().toUtc(),
          reviewedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          state: FsrsCardState.review,
        );

        await queue.enqueueReview(log);
        expect(queue.getPendingCount(), equals(1));

        // Attempt flush while unauthenticated
        final syncedCount = await queue.flushPendingLogs();

        // Verifies zero logs synced over wire, no HTTP calls dispatched, and log remains buffered locally
        expect(syncedCount, equals(0));
        expect(queue.getPendingCount(), equals(1));
        verifyZeroInteractions(mockDio);

        await queue.dispose();
      },
    );

    test(
      'flushPendingLogs uses Bearer user JWT when user is authenticated',
      () async {
        final mockDio = MockDio();
        final fakeStorage = _FakeLocalStorageService();
        final fakeUserStorage = _FakeUserStorageService()
          ..token = 'authenticated_jwt_token_456';

        final queue = CardSyncQueue(
          dio: mockDio,
          connectivity: mockConnectivity,
          storageService: fakeStorage,
          userStorageService: fakeUserStorage,
        );

        when(
          () => mockDio.post<dynamic>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          ),
        ).thenAnswer(
          (_) async => Response<dynamic>(
            requestOptions: RequestOptions(),
          ),
        );

        final log = FsrsReviewLog(
          id: '1',
          transactionUuid: 'uuid-auth-1',
          cardId: 'card-auth-1',
          rating: FsrsRating.good,
          stability: 2.5,
          difficulty: 4.8,
          elapsedDays: 1,
          scheduledDays: 3,
          reviewedAtUtc: DateTime.now().toUtc(),
          reviewedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          state: FsrsCardState.review,
        );

        await queue.enqueueReview(log);

        // Reviews are batched locally until the full deck is completed
        expect(queue.getPendingCount(), equals(1));
        verifyZeroInteractions(mockDio);

        // Deck completion triggers batch flush
        final syncedCount = await queue.flushPendingLogs();
        expect(syncedCount, equals(1));
        expect(queue.getPendingCount(), equals(0));

        final captured = verify(
          () => mockDio.post<dynamic>(
            any(that: contains('upsert_fsrs_review_batch')),
            data: any(named: 'data'),
            options: captureAny(named: 'options'),
          ),
        ).captured;

        final options = captured.first as Options;
        expect(options.headers?['Authorization'], equals('Bearer authenticated_jwt_token_456'));
        expect(options.headers?['apikey'], equals(AppEnv.apiKey));

        await queue.dispose();
      },
    );
  });
}
