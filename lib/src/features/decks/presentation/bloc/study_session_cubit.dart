import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/notification_service.dart';
import 'package:kortex/src/core/services/performance_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/save_session_results_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';

class StudySessionCubit extends Cubit<StudySessionState> {
  StudySessionCubit({
    required GetDeckCardsUseCase getDeckCardsUseCase,
    required SaveSessionResultsUseCase saveSessionResultsUseCase,
    FsrsScheduler? fsrsScheduler,
    CardSyncQueue? cardSyncQueue,
  }) : _getDeckCardsUseCase = getDeckCardsUseCase,
       _saveSessionResultsUseCase = saveSessionResultsUseCase,
       _fsrsScheduler = fsrsScheduler ?? FsrsScheduler(),
       _cardSyncQueue = cardSyncQueue ??
           (locator.isRegistered<CardSyncQueue>()
               ? locator<CardSyncQueue>()
               : CardSyncQueue()),
       super(const StudySessionState());

  final GetDeckCardsUseCase _getDeckCardsUseCase;
  final SaveSessionResultsUseCase _saveSessionResultsUseCase;
  final FsrsScheduler _fsrsScheduler;
  final CardSyncQueue _cardSyncQueue;

  /// Exposes active FsrsScheduler for testing and metrics.
  FsrsScheduler get fsrsScheduler => _fsrsScheduler;

  /// Exposes active CardSyncQueue for offline sync monitoring.
  CardSyncQueue get cardSyncQueue => _cardSyncQueue;

  Timer? _timer;

  Future<void> startSession(String deckId) async {
    emit(state.copyWith(status: StudySessionStatus.loading, deckId: deckId));

    final result = await _getDeckCardsUseCase(deckId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: StudySessionStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (cards) {
        if (cards.isEmpty) {
          emit(
            state.copyWith(
              status: StudySessionStatus.error,
              errorMessage: 'This deck currently has no cards.',
            ),
          );
          return;
        }

        emit(
          state.copyWith(
            status: StudySessionStatus.studying,
            cards: cards,
            currentIndex: 0,
            isFlipped: false,
            elapsedSeconds: 0,
          ),
        );

        _startTimer();
      },
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status == StudySessionStatus.studying) {
        emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
      }
    });
  }

  void toggleFlip() {
    if (state.status != StudySessionStatus.studying) return;
    emit(state.copyWith(isFlipped: !state.isFlipped));
  }

  void setFlipped({required bool isFlipped}) {
    if (state.status != StudySessionStatus.studying) return;
    emit(state.copyWith(isFlipped: isFlipped));
  }

  Future<void> rateCard(dynamic rating) async {
    if (state.status != StudySessionStatus.studying) return;

    final currentCard = state.currentCard;
    if (currentCard == null) return;

    // 1. Resolve input rating directly to FsrsRating
    final FsrsRating fsrsRating;
    if (rating is FsrsRating) {
      fsrsRating = rating;
    } else if (rating is int) {
      if (rating < 3) {
        fsrsRating = FsrsRating.again;
      } else if (rating == 3) {
        fsrsRating = FsrsRating.hard;
      } else if (rating == 4) {
        fsrsRating = FsrsRating.good;
      } else {
        fsrsRating = FsrsRating.easy;
      }
    } else {
      fsrsRating = FsrsRating.good;
    }

    // 2. Track ratings statistics
    var newAgain = state.againCount;
    var newHard = state.hardCount;
    var newGood = state.goodCount;
    var newEasy = state.easyCount;
    var newCorrect = state.correctCount;

    switch (fsrsRating) {
      case FsrsRating.again:
        newAgain++;
      case FsrsRating.hard:
        newCorrect++;
        newHard++;
      case FsrsRating.good:
        newCorrect++;
        newGood++;
      case FsrsRating.easy:
        newCorrect++;
        newEasy++;
    }

    // 3. FSRS-6 Review State Transition & UTC Timestamps
    final nowUtc = DateTime.now().toUtc();
    final lastReviewUtc = currentCard.lastReviewed?.toUtc();
    final elapsedDays = lastReviewUtc == null
        ? 0
        : nowUtc.difference(lastReviewUtc).inDays.clamp(0, 36500);

    final isNewCard =
        currentCard.repetitions == 0 && currentCard.lastReviewed == null;
    final initialStability =
        currentCard.interval > 0 ? currentCard.interval.toDouble() : 0.0;
    final initialDifficulty =
        ((3.0 - currentCard.easeFactor) * 5.0).clamp(1.0, 10.0);

    final fsrsCard = FsrsCard(
      cardId: currentCard.id,
      due: currentCard.nextDueDate?.toUtc(),
      stability: initialStability,
      difficulty: initialDifficulty,
      elapsedDays: elapsedDays,
      scheduledDays: currentCard.interval,
      reps: currentCard.repetitions,
      state: isNewCard ? FsrsCardState.newCard : FsrsCardState.review,
      lastReview: lastReviewUtc,
      lastReviewedEpoch: lastReviewUtc?.millisecondsSinceEpoch ?? 0,
    );

    final reviewResult = _fsrsScheduler.reviewCard(
      currentCard: fsrsCard,
      rating: fsrsRating,
      now: nowUtc,
    );

    // Retrievability score calculation
    // ignore: unused_local_variable
    final retrievabilityScore = _fsrsScheduler.retrievability(
      reviewResult.card.elapsedDays.toDouble(),
      reviewResult.card.stability,
    );

    // 4. Enqueue into CardSyncQueue for robust offline persistence & automatic flush
    unawaited(_cardSyncQueue.enqueueReview(reviewResult.log));

    // 5. Update flashcard entity with latest repetition, interval, and next due date
    final updatedCard = currentCard.copyWith(
      repetitions: reviewResult.card.reps,
      interval: reviewResult.card.scheduledDays,
      easeFactor: (3.0 - (reviewResult.card.difficulty / 5.0)).clamp(1.3, 2.5),
      lastReviewed: nowUtc,
      nextDueDate: reviewResult.card.due ??
          nowUtc.add(Duration(
              days: reviewResult.card.scheduledDays > 0
                  ? reviewResult.card.scheduledDays
                  : 1)),
    );

    final updatedCards = List<FlashcardEntity>.from(state.cards);
    if (state.currentIndex >= 0 && state.currentIndex < updatedCards.length) {
      updatedCards[state.currentIndex] = updatedCard;
    }

    if (state.isLastCard) {
      _timer?.cancel();
      final totalReviewed = updatedCards.length;
      final finalRetention =
          ((newHard * 0.7) + (newGood * 1.0) + (newEasy * 1.0)) /
          (totalReviewed == 0 ? 1 : totalReviewed);
      final mastered = newGood + newEasy;
      final remainingDue = updatedCards.where((c) => c.isDueToday).length;
      final calculatedMasteryRate = finalRetention.clamp(0.0, 1.0);

      // 1. Record in UserActivityService for persistent analytics & streak calculation
      try {
        await locator<UserActivityService>().recordStudySession(
          cardsReviewed: totalReviewed,
          durationSeconds: state.elapsedSeconds,
          retentionScore: finalRetention.clamp(0.0, 1.0),
          masteredCards: mastered,
        );
      } on Object catch (_) {}

      // 2. Persist updated cards locally and in-memory
      try {
        if (locator.isRegistered<DecksRemoteDataSource>()) {
          await locator<DecksRemoteDataSource>().updateDeckCards(
            state.deckId,
            updatedCards.map(FlashcardModel.fromEntity).toList(),
          );
        }
      } on Object catch (_) {}

      // 3. Save session results to backend API & recalculate deck mastery
      try {
        await _saveSessionResultsUseCase(
          SaveSessionResultsParams(
            deckId: state.deckId,
            cardsReviewed: totalReviewed,
            durationSeconds: state.elapsedSeconds,
            retentionScore: finalRetention.clamp(0.0, 1.0),
            masteryRate: calculatedMasteryRate,
            dueCards: remainingDue,
            updatedCards: updatedCards,
          ),
        );
      } on Object catch (_) {}

      // 4. Increment streak in AuthBloc
      try {
        locator<AuthBloc>().add(const AuthStreakIncremented());
      } on Object catch (_) {}

      // 5. Trigger live refresh on DecksBloc and DashboardBloc
      try {
        locator<DecksBloc>().add(const DecksRefreshed());
      } on Object catch (_) {}
      try {
        locator<DashboardBloc>().add(const DashboardRefreshed());
      } on Object catch (_) {}

      // 6. Telemetry: Performance trace and Crashlytics completion metrics
      try {
        final crashlytics = locator<CrashlyticsService>();
        unawaited(
          crashlytics.log(
            'Study session completed: deckId=${state.deckId}, cards=$totalReviewed, '
            'duration=${state.elapsedSeconds}s, retention=$finalRetention',
          ),
        );
        unawaited(crashlytics.setCustomKey('last_study_deck', state.deckId));
        unawaited(crashlytics.setCustomKey('last_study_cards', totalReviewed));

        final performance = locator<PerformanceService>();
        final trace = performance.newTrace('study_session_completion')
          ..putAttribute('deck_id', state.deckId)
          ..setMetric('cards_reviewed', totalReviewed)
          ..setMetric('duration_seconds', state.elapsedSeconds);
        unawaited(trace.start().then((_) => trace.stop()));
      } on Object catch (_) {}

      // 7. Re-evaluate deck review and streak reminders
      try {
        if (locator.isRegistered<NotificationService>()) {
          unawaited(locator<NotificationService>().checkAndTriggerDueReminders());
        }
      } on Object catch (_) {}

      // 7. Trigger flush of queued card reviews upon session completion
      unawaited(_cardSyncQueue.flushPendingLogs());

      emit(
        state.copyWith(
          status: StudySessionStatus.finished,
          cards: updatedCards,
          againCount: newAgain,
          hardCount: newHard,
          goodCount: newGood,
          easyCount: newEasy,
          correctCount: newCorrect,
        ),
      );
    } else {
      emit(
        state.copyWith(
          cards: updatedCards,
          currentIndex: state.currentIndex + 1,
          isFlipped: false,
          againCount: newAgain,
          hardCount: newHard,
          goodCount: newGood,
          easyCount: newEasy,
          correctCount: newCorrect,
        ),
      );
    }
  }

  /// Finishes session early at a sprint checkpoint without losing FSRS card progress.
  Future<void> finishEarly() async {
    if (state.status != StudySessionStatus.studying) return;
    _timer?.cancel();

    final totalReviewed = state.currentIndex;
    if (totalReviewed == 0) {
      emit(state.copyWith(status: StudySessionStatus.finished));
      return;
    }

    final finalRetention =
        ((state.hardCount * 0.7) + (state.goodCount * 1.0) + (state.easyCount * 1.0)) /
        (totalReviewed == 0 ? 1 : totalReviewed);
    final mastered = state.goodCount + state.easyCount;
    final remainingDue = state.cards.where((c) => c.isDueToday).length;
    final calculatedMasteryRate = finalRetention.clamp(0.0, 1.0);

    try {
      await locator<UserActivityService>().recordStudySession(
        cardsReviewed: totalReviewed,
        durationSeconds: state.elapsedSeconds,
        retentionScore: finalRetention.clamp(0.0, 1.0),
        masteredCards: mastered,
      );
    } on Object catch (_) {}

    try {
      if (locator.isRegistered<DecksRemoteDataSource>()) {
        await locator<DecksRemoteDataSource>().updateDeckCards(
          state.deckId,
          state.cards.map(FlashcardModel.fromEntity).toList(),
        );
      }
    } on Object catch (_) {}

    try {
      await _saveSessionResultsUseCase(
        SaveSessionResultsParams(
          deckId: state.deckId,
          cardsReviewed: totalReviewed,
          durationSeconds: state.elapsedSeconds,
          retentionScore: finalRetention.clamp(0.0, 1.0),
          masteryRate: calculatedMasteryRate,
          dueCards: remainingDue,
          updatedCards: state.cards,
        ),
      );
    } on Object catch (_) {}

    try {
      locator<AuthBloc>().add(const AuthStreakIncremented());
    } on Object catch (_) {}
    try {
      locator<DecksBloc>().add(const DecksRefreshed());
    } on Object catch (_) {}
    try {
      locator<DashboardBloc>().add(const DashboardRefreshed());
    } on Object catch (_) {}

    unawaited(_cardSyncQueue.flushPendingLogs());

    emit(
      state.copyWith(
        status: StudySessionStatus.finished,
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
