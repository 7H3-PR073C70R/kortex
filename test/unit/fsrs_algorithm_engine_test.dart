import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';

void main() {
  group('FsrsAlgorithmEngine FSRS-4.5 Unit Test Suite', () {
    const engine = FsrsAlgorithmEngine();

    test('first review assigns initial stability and difficulty by rating', () {
      final initial = FsrsCardState.initial();

      // Rating Good (3)
      final afterGood = engine.review(
        currentState: initial,
        rating: FsrsRating.good,
        reviewTime: DateTime(2026, 9, 1, 10),
      );

      expect(afterGood.reps, equals(1));
      expect(afterGood.stability, equals(2.4)); // w[2] = 2.4
      expect(afterGood.difficulty, equals(4.93)); // w[4] = 4.93
      expect(afterGood.scheduledDays, greaterThanOrEqualTo(2));
      expect(afterGood.lapses, equals(0));

      // Rating Easy (4)
      final afterEasy = engine.review(
        currentState: initial,
        rating: FsrsRating.easy,
        reviewTime: DateTime(2026, 9, 1, 10),
      );

      expect(afterEasy.stability, equals(5.8)); // w[3] = 5.8
      expect(afterEasy.difficulty, lessThan(4.93));
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
