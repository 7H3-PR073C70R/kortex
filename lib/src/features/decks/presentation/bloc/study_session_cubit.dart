import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/domain/use_cases/get_deck_cards_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/process_card_review_use_case.dart';
import 'package:kortex/src/features/decks/domain/use_cases/save_session_results_use_case.dart';
import 'package:kortex/src/features/decks/presentation/bloc/study_session_state.dart';

class StudySessionCubit extends Cubit<StudySessionState> {
  StudySessionCubit({
    required GetDeckCardsUseCase getDeckCardsUseCase,
    required ProcessCardReviewUseCase processCardReviewUseCase,
    required SaveSessionResultsUseCase saveSessionResultsUseCase,
  }) : _getDeckCardsUseCase = getDeckCardsUseCase,
       _processCardReviewUseCase = processCardReviewUseCase,
       _saveSessionResultsUseCase = saveSessionResultsUseCase,
       super(const StudySessionState());

  final GetDeckCardsUseCase _getDeckCardsUseCase;
  final ProcessCardReviewUseCase _processCardReviewUseCase;
  final SaveSessionResultsUseCase _saveSessionResultsUseCase;

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

  Future<void> rateCard(int quality) async {
    if (state.status != StudySessionStatus.studying) return;

    final currentCard = state.currentCard;
    if (currentCard == null) return;

    // Track ratings statistics
    var newAgain = state.againCount;
    var newHard = state.hardCount;
    var newGood = state.goodCount;
    var newEasy = state.easyCount;
    var newCorrect = state.correctCount;

    if (quality < 3) {
      newAgain++;
    } else {
      newCorrect++;
      if (quality == 3) {
        newHard++;
      } else if (quality == 4) {
        newGood++;
      } else if (quality == 5) {
        newEasy++;
      }
    }

    // Process SM-2 async
    unawaited(
      _processCardReviewUseCase(
        ProcessCardReviewParams(
          cardId: currentCard.id,
          quality: quality,
          previousInterval: currentCard.interval,
          previousRepetitions: currentCard.repetitions,
          previousEaseFactor: currentCard.easeFactor,
        ),
      ),
    );

    if (state.isLastCard) {
      _timer?.cancel();
      final totalReviewed = state.cards.length;
      final finalRetention =
          ((newHard * 0.7) + (newGood * 1.0) + (newEasy * 1.0)) /
          (totalReviewed == 0 ? 1 : totalReviewed);
      final mastered = newGood + newEasy;

      // 1. Record in UserActivityService for persistent analytics & streak calculation
      try {
        await locator<UserActivityService>().recordStudySession(
          cardsReviewed: totalReviewed,
          durationSeconds: state.elapsedSeconds,
          retentionScore: finalRetention.clamp(0.0, 1.0),
          masteredCards: mastered,
        );
      } on Object catch (_) {}

      // 2. Save session results to backend API
      unawaited(
        _saveSessionResultsUseCase(
          SaveSessionResultsParams(
            deckId: state.deckId,
            cardsReviewed: totalReviewed,
            durationSeconds: state.elapsedSeconds,
            retentionScore: finalRetention.clamp(0.0, 1.0),
          ),
        ),
      );

      // 3. Increment streak in AuthBloc
      try {
        locator<AuthBloc>().add(const AuthStreakIncremented());
      } on Object catch (_) {}

      // 4. Trigger live refresh on DashboardBloc
      try {
        locator<DashboardBloc>().add(const DashboardRefreshed());
      } on Object catch (_) {}

      emit(
        state.copyWith(
          status: StudySessionStatus.finished,
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

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
