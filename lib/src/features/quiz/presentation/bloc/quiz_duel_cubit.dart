import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_duel_repository.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';

/// Cubit managing 1v1 Quiz Duel multiplayer state transitions and real-time streams (QZ-13).
class QuizDuelCubit extends Cubit<QuizDuelState> {
  QuizDuelCubit({
    required QuizDuelRepository repository,
  })  : _repository = repository,
        super(const QuizDuelState());

  final QuizDuelRepository _repository;
  StreamSubscription<QuizDuelMatch>? _duelSubscription;
  Timer? _countdownTimer;
  DateTime? _roundStartTime;

  /// Starts searching for a real-time peer or AI study-buddy.
  Future<void> startMatchmaking({
    required String subject,
    required String examBoard,
    required String userId,
    required String displayName,
    required String avatarUrl,
  }) async {
    emit(state.copyWith(
      status: QuizDuelStatus.matching,
      currentUserId: userId,
      clearSelectedOption: true,
    ));

    final result = await _repository.findOrCreateDuel(
      subject: subject,
      examBoard: examBoard,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: QuizDuelStatus.cancelled,
          errorMessage: failure.message,
        ));
      },
      (match) {
        emit(state.copyWith(
          match: match,
          status: match.status,
        ));
        _subscribeToMatchStream(match.duelId);
      },
    );
  }

  void _subscribeToMatchStream(String duelId) {
    unawaited(_duelSubscription?.cancel());
    _duelSubscription = _repository.streamDuel(duelId).listen(
      (match) {
        final previousStatus = state.status;
        final previousQuestionIdx = state.match?.currentQuestionIndex;

        final isNewRound = match.status == QuizDuelStatus.inRound &&
            (previousStatus != QuizDuelStatus.inRound ||
                previousQuestionIdx != match.currentQuestionIndex);

        if (isNewRound) {
          _startQuestionCountdown(match.durationPerQuestionSeconds);
        }

        emit(state.copyWith(
          match: match,
          status: match.status,
          clearSelectedOption: isNewRound,
        ));
      },
      onError: (Object error) {
        emit(state.copyWith(
          errorMessage: 'Connection interrupted: $error',
        ));
      },
    );
  }

  void _startQuestionCountdown(int durationSeconds) {
    _countdownTimer?.cancel();
    _roundStartTime = DateTime.now();
    emit(state.copyWith(
      remainingSeconds: durationSeconds,
      clearSelectedOption: true,
    ));

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

    emit(state.copyWith(
      selectedOptionIndex: optionIndex,
      isSubmitting: true,
    ));

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

  @override
  Future<void> close() {
    _countdownTimer?.cancel();
    unawaited(_duelSubscription?.cancel());
    return super.close();
  }
}
