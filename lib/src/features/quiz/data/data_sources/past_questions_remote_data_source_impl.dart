import 'package:kortex/src/features/quiz/data/client/past_questions_api_client.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/data/models/seed_past_questions.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class PastQuestionsRemoteDataSourceImpl
    implements PastQuestionsRemoteDataSource {
  PastQuestionsRemoteDataSourceImpl(this._client);

  final PastQuestionsApiClient _client;

  Map<String, dynamic> _buildParams({
    String? examType,
    String? subject,
    int? year,
    String? searchQuery,
    int limit = 100,
  }) {
    final params = <String, dynamic>{
      'select': '*',
      'order': 'year.desc,question_number.asc',
      'limit': '$limit',
    };

    if (examType != null && examType.isNotEmpty && examType != 'ALL') {
      params['exam_type'] = 'ilike.%$examType%';
    }

    if (subject != null && subject.isNotEmpty && subject != 'All') {
      params['subject'] = 'ilike.%$subject%';
    }

    if (year != null) {
      params['year'] = 'eq.$year';
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      params['or'] = '(prompt.ilike.*$q*,topic.ilike.*$q*,subject.ilike.*$q*)';
    }

    return params;
  }

  @override
  Future<List<PastQuestionModel>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  }) async {
    try {
      final params = _buildParams(
        examType: examCategory?.code,
        subject: subject,
        year: year,
        searchQuery: searchQuery,
      );
      final res = await _client.fetchPastQuestions(params);
      final rows = res.data is List ? (res.data as List) : <dynamic>[];

      if (rows.isNotEmpty) {
        return rows
            .map((e) => PastQuestionModel.fromJson(e as Map<String, dynamic>))
            .toList();
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
      final params = _buildParams(examType: category.code);
      final res = await _client.fetchPastQuestions(params);
      final rows = res.data is List ? (res.data as List) : <dynamic>[];
      if (rows.isNotEmpty) {
        final set = <String>{};
        for (final row in rows) {
          if (row is Map<String, dynamic>) {
            final subj = row['subject'] as String?;
            if (subj != null && subj.isNotEmpty) {
              set.add(subj);
            }
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
      final params = _buildParams(examType: category.code);
      final res = await _client.fetchPastQuestions(params);
      final rows = res.data is List ? (res.data as List) : <dynamic>[];
      if (rows.isNotEmpty) {
        final set = <int>{};
        for (final row in rows) {
          if (row is Map<String, dynamic>) {
            final yr = (row['year'] as num?)?.toInt();
            if (yr != null) {
              set.add(yr);
            }
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
