import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';

void main() {
  group('FsrsAlgorithmEngine FSRS-6 Unit Test Suite', () {
    final engine = FsrsAlgorithmEngine();

    test('first review assigns initial stability and difficulty by rating', () {
      final initial = FsrsCardState.initial();

      // Rating Good (3)
      final afterGood = engine.review(
        currentState: initial,
        rating: FsrsRating.good,
        reviewTime: DateTime(2026, 9, 1, 10),
      );

      expect(afterGood.reps, equals(1));
      expect(afterGood.stability, equals(3.173)); // w[2] = 3.173
      expect(afterGood.difficulty, inInclusiveRange(1.0, 10.0));
      expect(afterGood.scheduledDays, greaterThanOrEqualTo(2));
      expect(afterGood.lapses, equals(0));

      // Rating Easy (4)
      final afterEasy = engine.review(
        currentState: initial,
        rating: FsrsRating.easy,
        reviewTime: DateTime(2026, 9, 1, 10),
      );

      expect(afterEasy.stability, equals(15.691)); // w[3] = 15.69105 -> 15.691
      expect(afterEasy.difficulty, lessThan(afterGood.difficulty));
    });

    test('consecutive recall increases stability and scheduled interval', () {
      final state1 = engine.review(
        currentState: FsrsCardState.initial(),
        rating: FsrsRating.good,
        reviewTime: DateTime(2026, 9, 2),
      );

      final state2 = engine.review(
        currentState: state1,
        rating: FsrsRating.good,
        reviewTime: DateTime(2026, 9, 4),
      );

      expect(state2.reps, equals(2));
      expect(state2.stability, greaterThan(state1.stability));
      expect(state2.scheduledDays, greaterThan(state1.scheduledDays));
    });

    test('lapse (Again) increases lapse counter and limits stability', () {
      final state1 = engine.review(
        currentState: FsrsCardState.initial(),
        rating: FsrsRating.good,
        reviewTime: DateTime(2026, 9, 2),
      );

      final stateLapse = engine.review(
        currentState: state1,
        rating: FsrsRating.again,
        reviewTime: DateTime(2026, 9, 10),
      );

      expect(stateLapse.lapses, equals(1));
      expect(stateLapse.stability, lessThanOrEqualTo(state1.stability));
      expect(stateLapse.scheduledDays, equals(1));
    });
  });
}
