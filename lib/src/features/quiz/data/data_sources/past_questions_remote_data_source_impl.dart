import 'package:kortex/src/features/quiz/data/client/supabase_past_questions_client.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/data/models/seed_past_questions.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class PastQuestionsRemoteDataSourceImpl
    implements PastQuestionsRemoteDataSource {
  PastQuestionsRemoteDataSourceImpl(this._client);

  final SupabasePastQuestionsClient _client;

  @override
  Future<List<PastQuestionModel>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  }) async {
    try {
      final rows = await _client.fetchPastQuestions(
        examType: examCategory?.code,
        subject: subject,
        year: year,
        searchQuery: searchQuery,
      );

      if (rows.isNotEmpty) {
        return rows.map(PastQuestionModel.fromJson).toList();
      }
    } on Object {
      // Fallback gracefully to offline seed cache if remote is initializing
    }

    return SeedPastQuestions.filter(
      examCategory: examCategory,
      subject: subject,
      year: year,
      searchQuery: searchQuery,
    );
  }

  @override
  Future<List<String>> getAvailableSubjects(ExamCategory category) async {
    try {
      final rows = await _client.fetchPastQuestions(
        examType: category.code,
      );
      if (rows.isNotEmpty) {
        final set = <String>{};
        for (final row in rows) {
          final subj = row['subject'] as String?;
          if (subj != null && subj.isNotEmpty) {
            set.add(subj);
          }
        }
        final list = set.toList()..sort();
        return list;
      }
    } on Object {
      // Fallback
    }

    final local = SeedPastQuestions.filter(examCategory: category);
    final set = local.map((q) => q.subject).toSet().toList()..sort();
    return set;
  }

  @override
  Future<List<int>> getAvailableYears(ExamCategory category) async {
    try {
      final rows = await _client.fetchPastQuestions(
        examType: category.code,
      );
      if (rows.isNotEmpty) {
        final set = <int>{};
        for (final row in rows) {
          final yr = (row['year'] as num?)?.toInt();
          if (yr != null) {
            set.add(yr);
          }
        }
        final list = set.toList()..sort((a, b) => b.compareTo(a));
        return list;
      }
    } on Object {
      // Fallback
    }

    final local = SeedPastQuestions.filter(examCategory: category);
    final set = local.map((q) => q.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    return set;
  }
}
