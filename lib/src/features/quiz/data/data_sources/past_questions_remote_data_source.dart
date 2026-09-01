import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

abstract class PastQuestionsRemoteDataSource {
  Future<List<PastQuestionModel>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  });

  Future<List<String>> getAvailableSubjects(ExamCategory category);

  Future<List<int>> getAvailableYears(ExamCategory category);
}
