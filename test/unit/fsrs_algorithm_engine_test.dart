import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/domain/entities/fsrs_card_state.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_algorithm_engine.dart';

void main() {
  group('FsrsAlgorithmEngine FSRS-6 Unit Test Suite', () {
    final engine = FsrsAlgorithmEngine();

    test('first review assigns initial stability and difficulty by rating', () {
      final initial = FsrsMemoryState.initial();

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
        currentState: FsrsMemoryState.initial(),
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
        currentState: FsrsMemoryState.initial(),
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

    test('acute assessment deadline compression clamps intervals to pre-exam horizon', () {
      // With stability = 20, standard next interval is > 10 days
      final unconstrained = engine.calculateNextInterval(20);
      expect(unconstrained, greaterThan(10));

      // With exam in 2 days (crunch), interval is clamped to 1
      final crunchInterval = engine.calculateNextInterval(20, daysUntilExam: 2);
      expect(crunchInterval, equals(1));

      // With exam in 6 days (week of exam), interval is clamped to at most 3 days (6 / 2)
      final weekInterval = engine.calculateNextInterval(20, daysUntilExam: 6);
      expect(weekInterval, equals(3));

      // Reviewing with rating Easy when exam is in 4 days clamps scheduledDays to <= 2
      final stateEasyCrunch = engine.review(
        currentState: FsrsMemoryState.initial(),
        rating: FsrsRating.easy,
        reviewTime: DateTime(2026, 9),
        daysUntilExam: 4,
      );
      expect(stateEasyCrunch.scheduledDays, lessThanOrEqualTo(2));
    });

    test('recalibratePostAssessment lifts artificial cram clamping back to natural spacing', () {
      // Create a card that was reviewed under acute cram pressure (clamped to 2 days)
      final reviewDate = DateTime(2026, 9, 10);
      final clampedState = engine.review(
        currentState: FsrsMemoryState.initial(),
        rating: FsrsRating.easy,
        reviewTime: reviewDate,
        daysUntilExam: 4,
      );

      // Verify it was clamped
      expect(clampedState.scheduledDays, lessThanOrEqualTo(2));
      final naturalInterval = engine.calculateNextInterval(clampedState.stability);
      expect(naturalInterval, greaterThan(clampedState.scheduledDays));

      // Now assessment has passed, recalibrate:
      final recalibrated = engine.recalibratePostAssessment(
        currentState: clampedState,
        referenceTime: DateTime(2026, 9, 15),
      );

      expect(recalibrated.scheduledDays, equals(naturalInterval));
      expect(
        recalibrated.nextDueDate,
        equals(clampedState.lastReview!.add(Duration(days: naturalInterval))),
      );

      // Batch recalibration also works
      final batch = engine.recalibrateBatch(
        states: [clampedState],
        referenceTime: DateTime(2026, 9, 15),
      );
      expect(batch.first.scheduledDays, equals(naturalInterval));
    });
  });
}
