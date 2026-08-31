import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/quiz_repository.dart';

class GenerateQuizFromDeckUseCase {
  const GenerateQuizFromDeckUseCase(this._repository);

  final QuizRepository _repository;

  Future<Either<Failure, List<QuizQuestionEntity>>> call({
    required String deckId,
    String? deckTitle,
    int questionCount = 10,
  }) {
    return _repository.generateQuizFromDeck(
      deckId: deckId,
      deckTitle: deckTitle,
      questionCount: questionCount,
    );
  }
}
