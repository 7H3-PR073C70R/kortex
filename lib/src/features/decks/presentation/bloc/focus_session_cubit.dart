import 'dart:async';
import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/utils/uuid_utils.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/data/data_sources/card_sync_queue.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/focus_session_config.dart';
import 'package:kortex/src/features/decks/domain/entities/thought_entry.dart';
import 'package:kortex/src/features/decks/domain/logic/fsrs_scheduler.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/save_session_results_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/focus_session_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';

class FocusSessionCubit extends Cubit<FocusSessionState> {
  FocusSessionCubit({
    GetDeckCardsUseCase? getDeckCardsUseCase,
    SaveSessionResultsUseCase? saveSessionResultsUseCase,
    FsrsScheduler? fsrsScheduler,
    CardSyncQueue? cardSyncQueue,
    LocalStorageService? localStorageService,
    TextToSpeechHandler? ttsHandler,
  })  : _getDeckCardsUseCase = getDeckCardsUseCase ??
            (locator.isRegistered<GetDeckCardsUseCase>()
                ? locator<GetDeckCardsUseCase>()
                : null),
        _saveSessionResultsUseCase = saveSessionResultsUseCase ??
            (locator.isRegistered<SaveSessionResultsUseCase>()
                ? locator<SaveSessionResultsUseCase>()
                : null),
        _fsrsScheduler = fsrsScheduler ??
            (locator.isRegistered<FsrsScheduler>()
                ? locator<FsrsScheduler>()
                : FsrsScheduler()),
        _cardSyncQueue = cardSyncQueue ??
            (locator.isRegistered<CardSyncQueue>()
                ? locator<CardSyncQueue>()
                : CardSyncQueue()),
        _localStorageService = localStorageService ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null),
        _ttsHandler = ttsHandler,
        super(const FocusSessionState()) {
    _initTtsListener();
  }

  final GetDeckCardsUseCase? _getDeckCardsUseCase;
  final SaveSessionResultsUseCase? _saveSessionResultsUseCase;
  final FsrsScheduler _fsrsScheduler;
  final CardSyncQueue _cardSyncQueue;
  final LocalStorageService? _localStorageService;
  final TextToSpeechHandler? _ttsHandler;

  static const String thoughtStorageKey = '__kortex_thought_parking_lot__';

  Timer? _timer;

  void _initTtsListener() {
    final handler = _ttsHandler;
    if (handler == null) return;
    handler.isSpeakingNotifier.addListener(() {
      final speaking = handler.isSpeakingNotifier.value;
      if (state.ttsSpeaking != speaking) {
        emit(state.copyWith(ttsSpeaking: speaking));
      }
    });
  }

  /// Starts or resumes a Hyperdrive focus session.
  /// If [preloadedCards] is given, uses them directly; otherwise queries [GetDeckCardsUseCase].
  Future<void> startSession({
    required String deckId,
    String sessionTitle = 'Hyperdrive Focus',
    List<FlashcardEntity>? preloadedCards,
    FocusSessionConfig config = const FocusSessionConfig(),
  }) async {
    emit(
      state.copyWith(
        status: FocusSessionStatus.loading,
        deckId: deckId,
        deckTitle: sessionTitle,
        config: config,
      ),
    );

    await _loadThoughts();

    List<FlashcardEntity> cards;
    if (preloadedCards != null && preloadedCards.isNotEmpty) {
      cards = preloadedCards;
    } else if (_getDeckCardsUseCase != null) {
      final result = await _getDeckCardsUseCase(deckId);
      final fetched = result.fold(
        (failure) {
          emit(
            state.copyWith(
              status: FocusSessionStatus.error,
              errorMessage: failure.message,
            ),
          );
          return <FlashcardEntity>[];
        },
        (data) => data,
      );
      if (fetched.isEmpty && state.status == FocusSessionStatus.error) {
        return;
      }
      cards = fetched;
    } else {
      cards = [];
    }

    if (cards.isEmpty) {
      emit(
        state.copyWith(
          status: FocusSessionStatus.error,
          errorMessage: 'No flashcards available for this focus session.',
        ),
      );
      return;
    }

    // Apply Backlog Mitigation if softCatchUp is requested
    List<FlashcardEntity> sessionCards;
    if (config.isSoftCatchUp) {
      sessionCards = _fsrsScheduler.softCatchUpReviewQueue<FlashcardEntity>(
        dueCards: cards,
        getStability: (c) => c.easeFactor,
        getLastReview: (c) => c.lastReviewed,
        sprintSize: config.targetCardCount,
      );
    } else {
      final shuffled = List<FlashcardEntity>.from(cards)..shuffle();
      sessionCards = shuffled.take(config.targetCardCount).toList();
    }

    final totalSeconds = config.type == FocusSessionType.timed
        ? config.targetDurationMinutes * 60
        : 0;

    emit(
      state.copyWith(
        status: FocusSessionStatus.active,
        cards: sessionCards,
        currentIndex: 0,
        isFlipped: false,
        elapsedSeconds: 0,
        remainingSeconds: totalSeconds,
        streak: 0,
        againCount: 0,
        hardCount: 0,
        goodCount: 0,
        easyCount: 0,
        correctCount: 0,
      ),
    );

    _startTimer();

    if (config.ttsAutoRead && sessionCards.isNotEmpty) {
      _speakText(sessionCards.first.front);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != FocusSessionStatus.active) return;
      final newElapsed = state.elapsedSeconds + 1;
      if (state.config.type == FocusSessionType.timed) {
        final newRemaining = state.remainingSeconds - 1;
        if (newRemaining <= 0) {
          emit(
            state.copyWith(
              elapsedSeconds: newElapsed,
              remainingSeconds: 0,
            ),
          );
          unawaited(
            _completeSession(
              state.cards,
              state.againCount,
              state.hardCount,
              state.goodCount,
              state.easyCount,
            ),
          );
        } else {
          emit(
            state.copyWith(
              elapsedSeconds: newElapsed,
              remainingSeconds: newRemaining,
            ),
          );
        }
      } else {
        emit(state.copyWith(elapsedSeconds: newElapsed));
      }
    });
  }

  void toggleFlip() {
    if (state.status != FocusSessionStatus.active) return;
    final nextFlipped = !state.isFlipped;
    emit(state.copyWith(isFlipped: nextFlipped));

    if (state.config.ttsAutoRead && state.currentCard != null) {
      final text = nextFlipped
          ? state.currentCard!.back
          : state.currentCard!.front;
      _speakText(text);
    }
  }

  void setFlipped({required bool isFlipped}) {
    if (state.status != FocusSessionStatus.active) return;
    emit(state.copyWith(isFlipped: isFlipped));
  }

  Future<void> rateCard(dynamic rating) async {
    if (state.status != FocusSessionStatus.active) return;

    final currentCard = state.currentCard;
    if (currentCard == null) return;

    // 1. Resolve rating to FSRS enum
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

    var newAgain = state.againCount;
    var newHard = state.hardCount;
    var newGood = state.goodCount;
    var newEasy = state.easyCount;
    var newCorrect = state.correctCount;
    var newStreak = state.streak;

    switch (fsrsRating) {
      case FsrsRating.again:
        newAgain++;
        newStreak = 0;
        AppFeedback.light();
      case FsrsRating.hard:
        newCorrect++;
        newHard++;
        newStreak++;
        AppFeedback.light();
      case FsrsRating.good:
        newCorrect++;
        newGood++;
        newStreak++;
        AppFeedback.medium();
      case FsrsRating.easy:
        newCorrect++;
        newEasy++;
        newStreak++;
        AppFeedback.medium();
    }

    // 2. FSRS State Transition
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

    unawaited(_cardSyncQueue.enqueueReview(reviewResult.log));

    final updatedCard = currentCard.copyWith(
      repetitions: reviewResult.card.reps,
      interval: reviewResult.card.scheduledDays,
      easeFactor: (3.0 - (reviewResult.card.difficulty / 5.0)).clamp(1.3, 2.5),
      lastReviewed: nowUtc,
      nextDueDate: reviewResult.card.due ??
          nowUtc.add(
            Duration(
              days: reviewResult.card.scheduledDays > 0
                  ? reviewResult.card.scheduledDays
                  : 1,
            ),
          ),
    );

    final updatedCards = List<FlashcardEntity>.from(state.cards);
    if (state.currentIndex >= 0 && state.currentIndex < updatedCards.length) {
      updatedCards[state.currentIndex] = updatedCard;
    }

    // Check completion condition
    if (state.isLastCard) {
      await _completeSession(
        updatedCards,
        newAgain,
        newHard,
        newGood,
        newEasy,
      );
    } else {
      final nextIndex = state.currentIndex + 1;
      emit(
        state.copyWith(
          cards: updatedCards,
          currentIndex: nextIndex,
          isFlipped: false,
          streak: newStreak,
          againCount: newAgain,
          hardCount: newHard,
          goodCount: newGood,
          easyCount: newEasy,
          correctCount: newCorrect,
        ),
      );

      if (state.config.ttsAutoRead && nextIndex < updatedCards.length) {
        _speakText(updatedCards[nextIndex].front);
      }
    }
  }

  Future<void> _completeSession(
    List<FlashcardEntity> finalCards,
    int again,
    int hard,
    int good,
    int easy,
  ) async {
    _timer?.cancel();
    await _ttsHandler?.stop();

    final totalReviewed = finalCards.length;
    final finalRetention =
        ((hard * 0.7) + (good * 1.0) + (easy * 1.0)) /
        (totalReviewed == 0 ? 1 : totalReviewed);
    final mastered = good + easy;
    final remainingDue = finalCards.where((c) => c.isDueToday).length;

    try {
      if (locator.isRegistered<UserActivityService>()) {
        await locator<UserActivityService>().recordStudySession(
          cardsReviewed: totalReviewed,
          durationSeconds: state.elapsedSeconds,
          retentionScore: finalRetention.clamp(0.0, 1.0),
          masteredCards: mastered,
        );
      }
    } on Object catch (_) {}

    try {
      if (locator.isRegistered<DecksRemoteDataSource>()) {
        await locator<DecksRemoteDataSource>().updateDeckCards(
          state.deckId,
          finalCards.map(FlashcardModel.fromEntity).toList(),
        );
      }
    } on Object catch (_) {}

    if (_saveSessionResultsUseCase != null) {
      try {
        await _saveSessionResultsUseCase(
          SaveSessionResultsParams(
            deckId: state.deckId,
            cardsReviewed: totalReviewed,
            durationSeconds: state.elapsedSeconds,
            retentionScore: finalRetention.clamp(0.0, 1.0),
            masteryRate: finalRetention.clamp(0.0, 1.0),
            dueCards: remainingDue,
          ),
        );
      } on Object catch (_) {}
    }

    AppFeedback.celebration();

    emit(
      state.copyWith(
        status: FocusSessionStatus.completed,
        cards: finalCards,
        againCount: again,
        hardCount: hard,
        goodCount: good,
        easyCount: easy,
        correctCount: hard + good + easy,
      ),
    );
  }

  void pauseSession() {
    if (state.status == FocusSessionStatus.active) {
      unawaited(_ttsHandler?.stop());
      emit(state.copyWith(status: FocusSessionStatus.paused));
    }
  }

  void resumeSession() {
    if (state.status == FocusSessionStatus.paused) {
      emit(state.copyWith(status: FocusSessionStatus.active));
    }
  }

  Future<void> completeEarly() async {
    if (state.status == FocusSessionStatus.active ||
        state.status == FocusSessionStatus.paused) {
      await _completeSession(
        state.cards,
        state.againCount,
        state.hardCount,
        state.goodCount,
        state.easyCount,
      );
    }
  }

  // --- Thought Parking Lot Handlers ---

  Future<void> parkThought(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final entry = ThoughtEntry(
      id: UuidUtils.generate(),
      content: trimmed,
      createdAt: DateTime.now(),
      sessionId: state.deckId,
      deckId: state.deckId,
    );

    final updated = [entry, ...state.parkedThoughts];
    emit(state.copyWith(parkedThoughts: updated));
    await _saveThoughts(updated);
    AppFeedback.selection();
  }

  Future<void> toggleThoughtResolved(String id) async {
    final updated = state.parkedThoughts.map((e) {
      if (e.id == id) {
        return e.copyWith(isResolved: !e.isResolved);
      }
      return e;
    }).toList();

    emit(state.copyWith(parkedThoughts: updated));
    await _saveThoughts(updated);
    AppFeedback.selection();
  }

  Future<void> deleteThought(String id) async {
    final updated = state.parkedThoughts.where((e) => e.id != id).toList();
    emit(state.copyWith(parkedThoughts: updated));
    await _saveThoughts(updated);
    AppFeedback.light();
  }

  Future<void> _loadThoughts() async {
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      if (storage == null) return;
      final raw = storage.getPreference(key: thoughtStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final thoughts = decoded
            .map((e) => ThoughtEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        emit(state.copyWith(parkedThoughts: thoughts));
      }
    } on Object catch (_) {}
  }

  Future<void> _saveThoughts(List<ThoughtEntry> thoughts) async {
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      if (storage == null) return;
      final raw = jsonEncode(thoughts.map((e) => e.toJson()).toList());
      await storage.savePreference(key: thoughtStorageKey, data: raw);
    } on Object catch (_) {}
  }

  // --- TTS & Audio Helpers ---

  void toggleTts() {
    final handler = _ttsHandler;
    if (handler == null) return;
    if (handler.isSpeaking) {
      unawaited(handler.stop());
      emit(state.copyWith(ttsSpeaking: false));
    } else {
      final card = state.currentCard;
      if (card != null) {
        final text = state.isFlipped ? card.back : card.front;
        _speakText(text);
      }
    }
  }

  void _speakText(String text) {
    final handler = _ttsHandler;
    if (handler != null && text.trim().isNotEmpty) {
      unawaited(handler.speak(text));
      emit(state.copyWith(ttsSpeaking: true));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    if (_ttsHandler != null) {
      unawaited(_ttsHandler.stop());
    }
    return super.close();
  }
}
