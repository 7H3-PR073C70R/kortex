import 'dart:math' as math;

enum FsrsRating {
  again(1),
  hard(2),
  good(3),
  easy(4);

  const FsrsRating(this.value);
  final int value;

  static FsrsRating fromValue(int val) {
    return FsrsRating.values.firstWhere(
      (r) => r.value == val,
      orElse: () => FsrsRating.good,
    );
  }
}

enum FsrsCardState {
  newCard(0),
  learning(1),
  review(2),
  relearning(3);

  const FsrsCardState(this.value);
  final int value;

  static FsrsCardState fromValue(int val) {
    return FsrsCardState.values.firstWhere(
      (s) => s.value == val,
      orElse: () => FsrsCardState.newCard,
    );
  }
}

/// Represents the spaced repetition state vector for a flashcard.
class FsrsCard {
  const FsrsCard({
    required this.cardId,
    this.due,
    this.stability = 0.0,
    this.difficulty = 0.0,
    this.elapsedDays = 0,
    this.scheduledDays = 0,
    this.reps = 0,
    this.lapses = 0,
    this.state = FsrsCardState.newCard,
    this.lastReview,
    this.lastReviewedEpoch = 0,
  });

  factory FsrsCard.fromMap(Map<String, dynamic> map) {
    return FsrsCard(
      cardId: map['card_id'] as String,
      due: map['due'] != null ? DateTime.parse(map['due'] as String) : null,
      stability: (map['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0.0,
      elapsedDays: map['elapsed_days'] as int? ?? 0,
      scheduledDays: map['scheduled_days'] as int? ?? 0,
      reps: map['reps'] as int? ?? 0,
      lapses: map['lapses'] as int? ?? 0,
      state: FsrsCardState.fromValue(map['state'] as int? ?? 0),
      lastReview: map['last_review'] != null
          ? DateTime.parse(map['last_review'] as String)
          : null,
      lastReviewedEpoch: map['last_reviewed_epoch'] as int? ?? 0,
    );
  }

  final String cardId;
  final DateTime? due;
  final double stability;
  final double difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final int reps;
  final int lapses;
  final FsrsCardState state;
  final DateTime? lastReview;
  final int lastReviewedEpoch;

  Map<String, dynamic> toMap() => {
        'card_id': cardId,
        'due': due?.toIso8601String(),
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'reps': reps,
        'lapses': lapses,
        'state': state.value,
        'last_review': lastReview?.toIso8601String(),
        'last_reviewed_epoch': lastReviewedEpoch,
      };

  FsrsCard copyWith({
    String? cardId,
    DateTime? due,
    double? stability,
    double? difficulty,
    int? elapsedDays,
    int? scheduledDays,
    int? reps,
    int? lapses,
    FsrsCardState? state,
    DateTime? lastReview,
    int? lastReviewedEpoch,
  }) {
    return FsrsCard(
      cardId: cardId ?? this.cardId,
      due: due ?? this.due,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      state: state ?? this.state,
      lastReview: lastReview ?? this.lastReview,
      lastReviewedEpoch: lastReviewedEpoch ?? this.lastReviewedEpoch,
    );
  }
}

/// Immutable record of a review event with UTC epoch timestamp and
/// client transaction UUID.
class FsrsReviewLog {
  const FsrsReviewLog({
    required this.id,
    required this.transactionUuid,
    required this.cardId,
    required this.rating,
    required this.stability,
    required this.difficulty,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.reviewedAtUtc,
    required this.reviewedAtEpoch,
    required this.state,
    this.isSynced = false,
  });

  factory FsrsReviewLog.fromMap(Map<String, dynamic> map) {
    return FsrsReviewLog(
      id: map['id'] as String,
      transactionUuid: map['transaction_uuid'] as String? ??
          'tx_${DateTime.now().microsecondsSinceEpoch}',
      cardId: map['card_id'] as String,
      rating: FsrsRating.fromValue(map['rating'] as int),
      stability: (map['stability'] as num?)?.toDouble() ?? 0.0,
      difficulty: (map['difficulty'] as num?)?.toDouble() ?? 0.0,
      elapsedDays: map['elapsed_days'] as int? ?? 0,
      scheduledDays: map['scheduled_days'] as int? ?? 1,
      reviewedAtUtc: DateTime.parse(map['reviewed_at_utc'] as String),
      reviewedAtEpoch: map['reviewed_at_epoch'] as int? ??
          DateTime.parse(map['reviewed_at_utc'] as String)
              .millisecondsSinceEpoch,
      state: FsrsCardState.fromValue(map['state'] as int? ?? 0),
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
    );
  }

  final String id;
  final String transactionUuid;
  final String cardId;
  final FsrsRating rating;
  final double stability;
  final double difficulty;
  final int elapsedDays;
  final int scheduledDays;
  final DateTime reviewedAtUtc;
  final int reviewedAtEpoch;
  final FsrsCardState state;
  final bool isSynced;

  Map<String, dynamic> toMap() => {
        'id': id,
        'transaction_uuid': transactionUuid,
        'card_id': cardId,
        'rating': rating.value,
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'reviewed_at_utc': reviewedAtUtc.toIso8601String(),
        'reviewed_at_epoch': reviewedAtEpoch,
        'state': state.value,
        'is_synced': isSynced ? 1 : 0,
      };

  Map<String, dynamic> toSupabasePayload() => {
        'transaction_uuid': transactionUuid,
        'card_id': cardId,
        'rating': rating.value,
        'stability': stability,
        'difficulty': difficulty,
        'elapsed_days': elapsedDays,
        'scheduled_days': scheduledDays,
        'reviewed_at_utc': reviewedAtUtc.toIso8601String(),
        'reviewed_at_epoch': reviewedAtEpoch,
        'state': state.value,
      };
}

/// Production implementation of Free Spaced Repetition Scheduler (FSRS v4.5).
class FsrsScheduler {
  FsrsScheduler({
    this.requestRetention = 0.9,
    this.maximumInterval = 36500,
    List<double>? weights,
  }) : w = weights ?? defaultWeights;

  final double requestRetention;
  final int maximumInterval;
  final List<double> w;

  /// Default 17 FSRS v4 parameter weights.
  static const List<double> defaultWeights = [
    0.40255, 1.18385, 3.173, 15.69105,
    7.1949, 0.5345, 1.4604, 0.0046,
    1.54575, 0.1192, 1.01925, 1.9395,
    0.11, 0.29605, 0.22695, 0.5698,
    2.0619,
  ];

  /// Calculates Retrievability R(t, S).
  double retrievability(double elapsedDays, double stability) {
    if (stability <= 0) return 0;
    return math.pow(1.0 + (19.0 / 81.0) * (elapsedDays / stability), -0.5)
        .toDouble();
  }

  /// Calculates initial stability for first review (Rating 1..4).
  double _initStability(FsrsRating rating) {
    final index = rating.value - 1;
    return math.max(0.1, w[index]);
  }

  /// Calculates initial difficulty for first review (Rating 1..4).
  double _initDifficulty(FsrsRating rating) {
    final d = w[4] - math.exp(w[5] * (rating.value - 1)) + 1.0;
    return d.clamp(1.0, 10.0);
  }

  /// Calculates next difficulty D'(D, G).
  double _nextDifficulty(double d, FsrsRating rating) {
    final deltaD = -w[6] * (rating.value - 3);
    final nextD = d + deltaD * ((10.0 - d) / 9.0);
    final meanReversion =
        w[7] * _initDifficulty(FsrsRating.easy) + (1 - w[7]) * nextD;
    return meanReversion.clamp(1.0, 10.0);
  }

  /// Calculates next stability on recall success S'_r(D, S, R, G).
  double _nextRecallStability(
    double d,
    double s,
    double r,
    FsrsRating rating,
  ) {
    final hardPenalty = rating == FsrsRating.hard ? w[15] : 1.0;
    final easyBonus = rating == FsrsRating.easy ? w[16] : 1.0;
    final sNext = s *
        (1.0 +
            math.exp(w[8]) *
                (11.0 - d) *
                math.pow(s, -w[9]) *
                (math.exp((1.0 - r) * w[10]) - 1.0) *
                hardPenalty *
                easyBonus);
    return math.max(0.1, sNext);
  }

  /// Calculates next stability on recall failure (lapse) S'_f(D, S, R).
  double _nextForgetStability(double d, double s, double r) {
    final sNext = w[11] *
        math.pow(d, -w[12]) *
        (math.pow(s + 1.0, w[13]) - 1.0) *
        math.exp((1.0 - r) * w[14]);
    return math.min(s, math.max(0.1, sNext));
  }

  /// Calculates next scheduled review interval from stability and
  /// target retention.
  int _nextInterval(double stability) {
    final newInterval =
        (stability / (19.0 / 81.0) * (math.pow(requestRetention, -2.0) - 1.0))
            .round();
    return newInterval.clamp(1, maximumInterval);
  }

  /// Executes rating review transition for a card, returning updated FsrsCard
  /// and the corresponding FsrsReviewLog with UTC timestamp & transaction UUID.
  ({FsrsCard card, FsrsReviewLog log}) reviewCard({
    required FsrsCard currentCard,
    required FsrsRating rating,
    DateTime? now,
    String? transactionUuid,
  }) {
    final reviewTime = (now ?? DateTime.now()).toUtc();
    final reviewEpoch = reviewTime.millisecondsSinceEpoch;
    final txUuid = transactionUuid ??
        'tx_${reviewEpoch}_${math.Random().nextInt(1000000)}';

    final elapsedDays = currentCard.lastReview == null
        ? 0
        : reviewTime.difference(currentCard.lastReview!).inDays;

    double nextS;
    double nextD;
    FsrsCardState nextState;

    if (currentCard.state == FsrsCardState.newCard) {
      // First review
      nextS = _initStability(rating);
      nextD = _initDifficulty(rating);
      nextState = rating == FsrsRating.again
          ? FsrsCardState.learning
          : FsrsCardState.review;
    } else {
      // Subsequent review
      final r = retrievability(elapsedDays.toDouble(), currentCard.stability);
      nextD = _nextDifficulty(currentCard.difficulty, rating);

      if (rating == FsrsRating.again) {
        nextS = _nextForgetStability(nextD, currentCard.stability, r);
        nextState = FsrsCardState.relearning;
      } else {
        nextS = _nextRecallStability(nextD, currentCard.stability, r, rating);
        nextState = FsrsCardState.review;
      }
    }

    final scheduledDays = _nextInterval(nextS);
    final due = reviewTime.add(Duration(days: scheduledDays));

    final updatedCard = currentCard.copyWith(
      stability: nextS,
      difficulty: nextD,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      reps: currentCard.reps + 1,
      lapses: rating == FsrsRating.again
          ? currentCard.lapses + 1
          : currentCard.lapses,
      state: nextState,
      lastReview: reviewTime,
      lastReviewedEpoch: reviewEpoch,
      due: due,
    );

    final log = FsrsReviewLog(
      id: 'log_${reviewEpoch}_${currentCard.cardId}',
      transactionUuid: txUuid,
      cardId: currentCard.cardId,
      rating: rating,
      stability: nextS,
      difficulty: nextD,
      elapsedDays: elapsedDays,
      scheduledDays: scheduledDays,
      reviewedAtUtc: reviewTime,
      reviewedAtEpoch: reviewEpoch,
      state: nextState,
    );

    return (card: updatedCard, log: log);
  }
}
