import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/services/study_activity_tracker.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';

/// Cubit managing 1v1 Quiz Duel multiplayer state transitions and real-time streams (QZ-13).
class QuizDuelCubit extends Cubit<QuizDuelState> {
  QuizDuelCubit({
    required QuizDuelRepository repository,
  }) : _repository = repository,
       super(const QuizDuelState());

  final QuizDuelRepository _repository;
  StreamSubscription<QuizDuelMatch>? _duelSubscription;
  Timer? _countdownTimer;
  DateTime? _roundStartTime;

  /// Starts searching for a real-time peer, joining by room code, or AI study-buddy.
  Future<void> startMatchmaking({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
    int questionCount = 10,
    String? roomCode,
  }) async {
    emit(
      state.copyWith(
        status: QuizDuelStatus.matching,
        currentUserId: userId,
        clearSelectedOption: true,
        clearFailure: true,
      ),
    );

    final result = await _repository.findOrCreateDuel(
      subject: subject,
      examBoard: examBoard,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      questionCount: questionCount,
      roomCode: roomCode,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: QuizDuelStatus.cancelled,
            errorMessage: failure.message,
            failure: failure,
          ),
        );
      },
      (match) {
        emit(
          state.copyWith(
            match: match,
            status: match.status,
            clearFailure: true,
          ),
        );
        _subscribeToMatchStream(match.duelId);
      },
    );
  }

  String? _subscribedDuelId;

  void _subscribeToMatchStream(String duelId) {
    if (_subscribedDuelId == duelId && _duelSubscription != null) return;
    _subscribedDuelId = duelId;

    unawaited(_duelSubscription?.cancel());
    _duelSubscription = _repository
        .streamDuel(duelId)
        .listen(
          (match) {
            if (match.duelId.isNotEmpty && match.duelId != duelId) {
              _subscribeToMatchStream(match.duelId);
            }

            final previousStatus = state.status;
            final previousQuestionIdx = state.match?.currentQuestionIndex;

            final isMatchCountdown =
                match.status == QuizDuelStatus.countdown &&
                (previousStatus != QuizDuelStatus.countdown ||
                    state.remainingSeconds <= 0);

            final isNewRound =
                match.status == QuizDuelStatus.inRound &&
                (previousStatus != QuizDuelStatus.inRound ||
                    previousQuestionIdx != match.currentQuestionIndex);

            final isJustFinished =
                match.status == QuizDuelStatus.finished &&
                previousStatus != QuizDuelStatus.finished;

            if (isMatchCountdown) {
              _startLobbyCountdown(3);
            } else if (isNewRound) {
              _startQuestionCountdown(match.durationPerQuestionSeconds);
            } else if (match.status == QuizDuelStatus.roundSummary) {
              _countdownTimer?.cancel();
            } else if (isJustFinished) {
              _countdownTimer?.cancel();
              unawaited(_repository.recordDuelOutcome(match));
              if (locator.isRegistered<UserActivityService>()) {
                final isWinner = match.winnerUserId == state.currentUserId;
                unawaited(
                  locator<UserActivityService>().awardXp(
                    isWinner
                        ? XpActivityCategory.quizDuelWin
                        : XpActivityCategory.quizDuelParticipation,
                    sourceId: match.duelId,
                    metadata: {'isWinner': isWinner, 'subject': match.subject},
                  ),
                );
              }
              if (locator.isRegistered<StudyActivityTracker>()) {
                final totalDuelDuration =
                    match.questions.length * match.durationPerQuestionSeconds;
                unawaited(
                  locator<StudyActivityTracker>().recordActivityCompletion(
                    durationSeconds:
                        totalDuelDuration > 0 ? totalDuelDuration : 60,
                    activityType: 'duel',
                    metadata: {
                      'duelId': match.duelId,
                      'subject': match.subject,
                    },
                  ),
                );
              }
            }

            emit(
              state.copyWith(
                match: match,
                status: match.status,
                clearSelectedOption: isNewRound,
              ),
            );
          },
          onError: (Object error) {
            emit(
              state.copyWith(
                errorMessage: 'Connection interrupted: $error',
              ),
            );
          },
        );
  }

  void _startLobbyCountdown(int durationSeconds) {
    _countdownTimer?.cancel();
    emit(
      state.copyWith(
        remainingSeconds: durationSeconds,
      ),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != QuizDuelStatus.countdown) {
        timer.cancel();
        return;
      }
      final current = state.remainingSeconds;
      if (current <= 1) {
        timer.cancel();
        emit(state.copyWith(remainingSeconds: 0));
      } else {
        emit(state.copyWith(remainingSeconds: current - 1));
      }
    });
  }

  void _startQuestionCountdown(int durationSeconds) {
    _countdownTimer?.cancel();
    _roundStartTime = DateTime.now();
    emit(
      state.copyWith(
        remainingSeconds: durationSeconds,
        clearSelectedOption: true,
      ),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = state.remainingSeconds;
      if (current <= 1) {
        timer.cancel();
        emit(state.copyWith(remainingSeconds: 0));
      } else {
        emit(state.copyWith(remainingSeconds: current - 1));
      }
    });
  }

  /// Submits the local player's answer for the current active question.
  Future<void> submitAnswer(int optionIndex) async {
    if (state.match == null ||
        state.status != QuizDuelStatus.inRound ||
        state.selectedOptionIndex != null) {
      return;
    }

    final responseTimeMs = _roundStartTime != null
        ? DateTime.now().difference(_roundStartTime!).inMilliseconds
        : 1000;

    emit(
      state.copyWith(
        selectedOptionIndex: optionIndex,
        isSubmitting: true,
      ),
    );

    await _repository.submitDuelAnswer(
      duelId: state.match!.duelId,
      userId: state.currentUserId,
      questionIndex: state.match!.currentQuestionIndex,
      optionIndex: optionIndex,
      responseTimeMs: responseTimeMs,
    );

    emit(state.copyWith(isSubmitting: false));
  }

  /// Broadcasts an in-game reaction emote (e.g. 🔥, ⚡, 🤯, 👏).
  Future<void> sendEmote(String emote) async {
    if (state.match == null) return;
    await _repository.sendDuelEmote(
      duelId: state.match!.duelId,
      userId: state.currentUserId,
      emote: emote,
    );
  }

  /// Exits the current match and frees resources.
  Future<void> leaveMatch() async {
    _countdownTimer?.cancel();
    if (state.match != null) {
      await _repository.leaveDuel(
        duelId: state.match!.duelId,
        userId: state.currentUserId,
      );
    }
    await _duelSubscription?.cancel();
    emit(const QuizDuelState(status: QuizDuelStatus.cancelled));
  }

  /// Instantly matches with AI bot if user prefers not to wait out the 2-minute search.
  Future<void> matchWithAiImmediately() async {
    if (state.match == null || state.status != QuizDuelStatus.matching) return;
    await _repository.matchWithAiImmediately(duelId: state.match!.duelId);
  }

  /// Requests or accepts a rematch with the duel opponent.
  Future<void> requestRematch() async {
    final currentMatch = state.match;
    if (currentMatch == null) return;

    emit(state.copyWith(isRematchLoading: true));

    final result = await _repository.requestRematch(
      duelId: currentMatch.duelId,
      userId: state.currentUserId,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isRematchLoading: false,
            errorMessage: failure.message,
          ),
        );
      },
      (match) {
        final isNewMatch = match.duelId != currentMatch.duelId;
        if (isNewMatch) {
          _subscribeToMatchStream(match.duelId);
        }
        emit(
          state.copyWith(
            match: match,
            status: match.status,
            isRematchLoading: false,
          ),
        );
      },
    );
  }

  /// Accepts a rematch challenge requested by rival.
  Future<void> acceptRematch() async {
    final currentMatch = state.match;
    if (currentMatch == null) return;

    emit(state.copyWith(isRematchLoading: true));

    final result = await _repository.acceptRematch(
      duelId: currentMatch.duelId,
      userId: state.currentUserId,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            isRematchLoading: false,
            errorMessage: failure.message,
          ),
        );
      },
      (match) {
        if (match.duelId != currentMatch.duelId) {
          _subscribeToMatchStream(match.duelId);
        }
        emit(
          state.copyWith(
            match: match,
            status: match.status,
            isRematchLoading: false,
          ),
        );
      },
    );
  }

  /// Declines or cancels an active rematch request.
  Future<void> declineRematch() async {
    final currentMatch = state.match;
    if (currentMatch == null) return;

    emit(state.copyWith(isRematchLoading: false));

    await _repository.declineRematch(
      duelId: currentMatch.duelId,
      userId: state.currentUserId,
    );

    emit(
      state.copyWith(
        match: currentMatch.copyWith(clearRematch: true),
        isRematchLoading: false,
      ),
    );
  }

  /// Starts an instant AI rematch if human peer is unresponsive or player prefers AI.
  Future<void> rematchWithAiImmediately() async {
    final currentMatch = state.match;
    if (currentMatch == null) return;

    emit(state.copyWith(isRematchLoading: true));

    final p1 = state.myParticipant;
    await startMatchmaking(
      subject: currentMatch.subject,
      examBoard: currentMatch.examBoard,
      userId: state.currentUserId,
      displayName: p1?.displayName ?? 'Scholar',
      avatarUrl: p1?.avatarUrl ?? '⚡',
      questionCount: currentMatch.questions.length,
    );

    await matchWithAiImmediately();
    emit(state.copyWith(isRematchLoading: false));
  }

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    unawaited(_duelSubscription?.cancel());
    return super.close();
  }
}
