import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class SeedPastQuestions {
  const SeedPastQuestions._();

  static List<PastQuestionModel> filter({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  }) {
    // Purged generic past questions. Returns empty list until genuine verified questions are synced.
    return const [];
  }

  static const List<PastQuestionModel> all = [];
}
