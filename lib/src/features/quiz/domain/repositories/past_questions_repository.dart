import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

abstract class PastQuestionsRepository {
  Future<Either<Failure, List<PastQuestionEntity>>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  });

  Future<Either<Failure, List<String>>> getAvailableSubjects(
    ExamCategory category,
  );

  Future<Either<Failure, List<int>>> getAvailableYears(
    ExamCategory category,
  );

  Future<Either<Failure, void>> toggleBookmarkQuestion(String questionId);
}
