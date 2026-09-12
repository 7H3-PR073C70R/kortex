import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';

/// State of the QuizDuelCubit.
class QuizDuelState extends Equatable {
  const QuizDuelState({
    this.match,
    this.status = QuizDuelStatus.matching,
    this.remainingSeconds = 15,
    this.selectedOptionIndex,
    this.currentUserId = 'current_user',
    this.errorMessage,
    this.isSubmitting = false,
  });

  final QuizDuelMatch? match;
  final QuizDuelStatus status;
  final int remainingSeconds;
  final int? selectedOptionIndex;
  final String currentUserId;
  final String? errorMessage;
  final bool isSubmitting;

  QuizDuelParticipant? get myParticipant {
    if (match == null) return null;
    if (match!.player1.userId == currentUserId) return match!.player1;
    if (match!.player2?.userId == currentUserId) return match!.player2;
    return match!.player1;
  }

  QuizDuelParticipant? get opponentParticipant {
    if (match == null) return null;
    if (match!.player1.userId == currentUserId) return match!.player2;
    return match!.player1;
  }

  bool get isMyAnswerLocked => selectedOptionIndex != null;

  bool get isWinner =>
      match?.winnerUserId != null && match?.winnerUserId == currentUserId;

  bool get isDraw => match?.isDraw ?? false;

  QuizDuelState copyWith({
    QuizDuelMatch? match,
    QuizDuelStatus? status,
    int? remainingSeconds,
    int? selectedOptionIndex,
    String? currentUserId,
    String? errorMessage,
    bool? isSubmitting,
    bool clearSelectedOption = false,
  }) {
    return QuizDuelState(
      match: match ?? this.match,
      status: status ?? this.status,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      selectedOptionIndex: clearSelectedOption
          ? null
          : (selectedOptionIndex ?? this.selectedOptionIndex),
      currentUserId: currentUserId ?? this.currentUserId,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [
        match,
        status,
        remainingSeconds,
        selectedOptionIndex,
        currentUserId,
        errorMessage,
        isSubmitting,
      ];
}
