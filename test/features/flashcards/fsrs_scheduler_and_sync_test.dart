import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/flashcards/data/datasources/card_sync_queue.dart';
import 'package:kortex/src/features/flashcards/domain/logic/fsrs_scheduler.dart';
import 'package:mocktail/mocktail.dart';

class MockConnectivity extends Mock implements Connectivity {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FsrsScheduler Algorithm & Review Cycle Test Suite', () {
    late FsrsScheduler scheduler;

    setUp(() {
      scheduler = FsrsScheduler();
    });

    test('Review generates UTC timestamps and unique transaction UUIDs', () {
      const initialCard = FsrsCard(cardId: 'card_math_101');

      final review = scheduler.reviewCard(
        currentCard: initialCard,
        rating: FsrsRating.good,
        now: DateTime.utc(2026, 8, 31, 12),
        transactionUuid: 'tx_custom_123',
      );

      expect(review.card.reps, equals(1));
      expect(review.card.lastReviewedEpoch, equals(1788177600000));
      expect(review.log.transactionUuid, equals('tx_custom_123'));
      expect(review.log.reviewedAtUtc.isUtc, isTrue);

      final payload = review.log.toSupabasePayload();
      expect(payload['transaction_uuid'], equals('tx_custom_123'));
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
  });
}
