import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_result_entity.dart';

abstract class QuizRepository {
  Future<Either<Failure, List<QuizQuestionEntity>>> generateQuizFromDeck({
    required String deckId,
    String? deckTitle,
    int questionCount = 10,
  });

  Future<Either<Failure, List<QuizQuestionEntity>>> generateQuizFromDocument({
    required String documentId,
    int questionCount = 10,
  });

  Future<Either<Failure, QuizResultEntity>> submitQuizAnswers({
    required String quizTitle,
    required List<QuizQuestionEntity> questions,
    required int durationSeconds,
    String? attemptId,
  });

  Future<Either<Failure, Map<String, dynamic>>> submitCbtMockAttempt({
    required String sessionId,
    required String quizTitle,
    required String subject,
    required int totalQuestions,
    required int correctAnswers,
    required int durationSeconds,
    List<String> weakSubtopics = const [],
    String? courseId,
    String? courseCode,
  });

  Future<int> flushPendingQuizSubmissions({bool force = false});
}
