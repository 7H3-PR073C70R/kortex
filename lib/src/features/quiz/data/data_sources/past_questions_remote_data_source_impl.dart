import 'package:kortex/src/features/quiz/data/client/past_questions_api_client.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

class PastQuestionsRemoteDataSourceImpl
    implements PastQuestionsRemoteDataSource {
  PastQuestionsRemoteDataSourceImpl(this._client);

  final PastQuestionsApiClient _client;
  final List<PastQuestionModel> _inMemoryQuestions = [];

  @override
  Future<void> savePastQuestions(List<PastQuestionModel> questions) async {
    if (questions.isEmpty) return;
    _inMemoryQuestions.insertAll(0, questions);

    try {
      final payload = questions.map((q) => q.toJson()).toList();
      await _client.insertPastQuestions(payload);
    } on Object {
      // Gracefully continue offline
    }
  }

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
    final memoryMatches = _inMemoryQuestions.where((q) {
      if (examCategory != null && q.examType != examCategory) return false;
      if (subject != null &&
          subject != 'All' &&
          !q.subject.toLowerCase().contains(subject.toLowerCase())) {
        return false;
      }
      if (year != null && q.year != year) return false;
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return q.prompt.toLowerCase().contains(query) ||
            q.subject.toLowerCase().contains(query) ||
            q.topic.toLowerCase().contains(query);
      }
      return true;
    }).toList();

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
        final remote = rows
            .map((e) => PastQuestionModel.fromJson(e as Map<String, dynamic>))
            .toList();

        final seenIds = memoryMatches.map((e) => e.id).toSet();
        return [
          ...memoryMatches,
          ...remote.where((q) => !seenIds.contains(q.id)),
        ];
      }
    } on Object {
      // Fallback gracefully to memory matches if remote query fails
    }

    return memoryMatches;
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

    return const [
      'English Language',
      'Mathematics',
      'Biology',
      'Chemistry',
      'Physics',
      'Economics',
      'Government',
      'Literature in English',
      'Commerce',
      'Agricultural Science',
      'Civic Education',
    ];
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
        if (set.isNotEmpty) {
          final list = set.toList()..sort((a, b) => b.compareTo(a));
          return list;
        }
      }
    } on Object {
      // Fallback
    }

    return const [2024, 2023, 2022, 2021, 2020, 2019, 2018];
  }
}
