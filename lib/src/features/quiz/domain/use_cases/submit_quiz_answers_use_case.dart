import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';

class SubmitQuizAnswersUseCase {
  const SubmitQuizAnswersUseCase(this._repository);

  final QuizRepository _repository;

  Future<Either<Failure, QuizResultEntity>> call({
    required String quizTitle,
    required List<QuizQuestionEntity> questions,
    required int durationSeconds,
  }) {
    return _repository.submitQuizAnswers(
      quizTitle: quizTitle,
      questions: questions,
      durationSeconds: durationSeconds,
    );
  }
}
