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
    this.result,
    this.errorMessage,
  });

  final QuizSessionStatus status;
  final String quizTitle;
  final List<QuizQuestionEntity> questions;
  final int currentIndex;
  final int elapsedSeconds;
  final QuizResultEntity? result;
  final String? errorMessage;

  QuizQuestionEntity? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  bool get isLastQuestion =>
      questions.isNotEmpty && currentIndex == questions.length - 1;

  int get totalQuestions => questions.length;

  int get answeredCount => questions.where((q) => q.isAnswered).length;

  String get formattedTimer {
    final minutes = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  QuizSessionState copyWith({
    QuizSessionStatus? status,
    String? quizTitle,
    List<QuizQuestionEntity>? questions,
    int? currentIndex,
    int? elapsedSeconds,
    QuizResultEntity? result,
    String? errorMessage,
  }) {
    return QuizSessionState(
      status: status ?? this.status,
      quizTitle: quizTitle ?? this.quizTitle,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
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
        result,
        errorMessage,
      ];
}
