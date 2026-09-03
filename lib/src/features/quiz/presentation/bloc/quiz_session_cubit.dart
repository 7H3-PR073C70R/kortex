import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/generate_quiz_from_deck_use_case.dart';
import 'package:kortex/src/features/quiz/domain/use_cases/submit_quiz_answers_use_case.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';

class QuizSessionCubit extends Cubit<QuizSessionState> {
  QuizSessionCubit({
    required GenerateQuizFromDeckUseCase generateQuizUseCase,
    required SubmitQuizAnswersUseCase submitQuizUseCase,
  }) : _generateQuizUseCase = generateQuizUseCase,
       _submitQuizUseCase = submitQuizUseCase,
       super(const QuizSessionState());

  final GenerateQuizFromDeckUseCase _generateQuizUseCase;
  final SubmitQuizAnswersUseCase _submitQuizUseCase;
  Timer? _timer;

  /// Starts a new quiz session from a deck.
  Future<void> startQuizFromDeck({
    required String deckId,
    String? deckTitle,
    int questionCount = 10,
  }) async {
    _timer?.cancel();
    emit(
      state.copyWith(
        status: QuizSessionStatus.loading,
        quizTitle: deckTitle ?? 'Practice Quiz',
      ),
    );

    final result = await _generateQuizUseCase(
      deckId: deckId,
      deckTitle: deckTitle,
      questionCount: questionCount,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: QuizSessionStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (questions) {
        emit(
          state.copyWith(
            status: QuizSessionStatus.inProgress,
            questions: questions,
            currentIndex: 0,
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
      if (state.status == QuizSessionStatus.inProgress ||
          state.status == QuizSessionStatus.questionAnswered) {
        emit(state.copyWith(elapsedSeconds: state.elapsedSeconds + 1));
      }
    });
  }

  /// Selects an answer option for the current question.
  void selectOption(String option) {
    if (state.currentQuestion == null) return;
    if (state.currentQuestion!.isAnswered) return;

    final current = state.currentQuestion!;
    final isCorrect =
        current.correctAnswer.trim().toLowerCase() ==
        option.trim().toLowerCase();

    final updatedQuestion = current.copyWith(
      userSelectedAnswer: option,
      isAnswered: true,
      isCorrect: isCorrect,
    );

    final updatedList = List<QuizQuestionEntity>.from(state.questions);
    updatedList[state.currentIndex] = updatedQuestion;

    emit(
      state.copyWith(
        status: QuizSessionStatus.questionAnswered,
        questions: updatedList,
      ),
    );
  }

  /// Advances to the next question.
  void nextQuestion() {
    if (state.isLastQuestion) return;

    emit(
      state.copyWith(
        status: QuizSessionStatus.inProgress,
        currentIndex: state.currentIndex + 1,
      ),
    );
  }

  /// Submits all completed answers and computes result with topic weaknesses.
  Future<void> submitQuiz() async {
    _timer?.cancel();
    emit(state.copyWith(status: QuizSessionStatus.loading));

    final result = await _submitQuizUseCase(
      quizTitle: state.quizTitle,
      questions: state.questions,
      durationSeconds: state.elapsedSeconds,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: QuizSessionStatus.error,
          errorMessage: failure.message,
        ),
      ),
      (quizResult) {
        emit(
          state.copyWith(
            status: QuizSessionStatus.completed,
            result: quizResult,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
