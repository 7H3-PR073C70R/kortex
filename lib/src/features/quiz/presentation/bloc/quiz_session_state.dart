import 'package:equatable/equatable.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

enum QuizSessionStatus {
  initial,
  loading,
  inProgress,
  questionAnswered,
  completed,
  error,
}

class QuizSessionState extends Equatable {
  const QuizSessionState({
    this.status = QuizSessionStatus.initial,
    this.quizTitle = 'Practice Quiz',
    this.questions = const [],
    this.currentIndex = 0,
    this.elapsedSeconds = 0,
    this.durationMinutes,
    this.flaggedQuestionIds = const {},
    this.result,
    this.errorMessage,
  });

  final QuizSessionStatus status;
  final String quizTitle;
  final List<QuizQuestionEntity> questions;
  final int currentIndex;
  final int elapsedSeconds;
  final int? durationMinutes;
  final Set<String> flaggedQuestionIds;
  final QuizResultEntity? result;
  final String? errorMessage;

  QuizQuestionEntity? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  bool get isLastQuestion =>
      questions.isNotEmpty && currentIndex == questions.length - 1;

  bool get canGoPrevious => currentIndex > 0;
  bool get canGoNext => currentIndex < questions.length - 1;

  int get totalQuestions => questions.length;

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  int get unansweredCount => totalQuestions - answeredCount;

  int get flaggedCount => flaggedQuestionIds.length;

  bool isQuestionFlagged(String? questionId) {
    if (questionId == null) return false;
    return flaggedQuestionIds.contains(questionId);
  }

  bool get isCurrentQuestionFlagged => isQuestionFlagged(currentQuestion?.id);

  int get remainingSeconds {
    if (durationMinutes == null) return 0;
    final totalSecs = durationMinutes! * 60;
    return totalSecs - elapsedSeconds;
  }

  bool get isTimeExpired => durationMinutes != null && remainingSeconds <= 0;

  bool get isTimeRunningLow =>
      durationMinutes != null && remainingSeconds > 0 && remainingSeconds <= 300;

  String get formattedTimer {
    final secs = durationMinutes != null
        ? (remainingSeconds < 0 ? 0 : remainingSeconds)
        : elapsedSeconds;
    final minutes = (secs ~/ 60).toString().padLeft(2, '0');
    final seconds = (secs % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  QuizSessionState copyWith({
    QuizSessionStatus? status,
    String? quizTitle,
    List<QuizQuestionEntity>? questions,
    int? currentIndex,
    int? elapsedSeconds,
    int? durationMinutes,
    Set<String>? flaggedQuestionIds,
    QuizResultEntity? result,
    String? errorMessage,
  }) {
    return QuizSessionState(
      status: status ?? this.status,
      quizTitle: quizTitle ?? this.quizTitle,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      flaggedQuestionIds: flaggedQuestionIds ?? this.flaggedQuestionIds,
      result: result ?? this.result,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    quizTitle,
    questions,
    currentIndex,
    elapsedSeconds,
    durationMinutes,
    flaggedQuestionIds,
    result,
    errorMessage,
  ];
}
