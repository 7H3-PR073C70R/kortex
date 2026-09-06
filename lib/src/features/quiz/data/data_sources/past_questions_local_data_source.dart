import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';

abstract class PastQuestionsLocalDataSource {
  Future<void> initialize();

  bool get isInitialized;

  Future<List<PastQuestionModel>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
    int limit = 100,
  });

  Future<List<String>> getAvailableSubjects(ExamCategory category);

  Future<List<int>> getAvailableYears(ExamCategory category);
}

class PastQuestionsLocalDataSourceImpl implements PastQuestionsLocalDataSource {
  PastQuestionsLocalDataSourceImpl({
    AssetBundle? assetBundle,
    String assetPath = 'assets/data/past_questions.json',
  })  : _assetBundle = assetBundle ?? rootBundle,
        _assetPath = assetPath;

  final AssetBundle _assetBundle;
  final String _assetPath;

  List<PastQuestionModel>? _cachedQuestions;
  final Map<ExamCategory, List<PastQuestionModel>> _byCategory = {};
  final Map<ExamCategory, List<String>> _subjectsByCategory = {};
  final Map<ExamCategory, List<int>> _yearsByCategory = {};

  @override
  bool get isInitialized => _cachedQuestions != null;

  @override
  Future<void> initialize() async {
    if (_cachedQuestions != null) return;

    try {
      final jsonString = await _assetBundle.loadString(_assetPath);
      final dynamic decoded = jsonDecode(jsonString);

      if (decoded is List) {
        final parsed = decoded
            .whereType<Map<String, dynamic>>()
            .map(PastQuestionModel.fromJson)
            .toList();

        _cachedQuestions = parsed;
        _buildIndices(parsed);
      } else {
        _cachedQuestions = const [];
      }
    } on Object {
      _cachedQuestions = const [];
    }
  }

  void _buildIndices(List<PastQuestionModel> questions) {
    _byCategory.clear();
    _subjectsByCategory.clear();
    _yearsByCategory.clear();

    final categorySubjectsMap = <ExamCategory, Set<String>>{};
    final categoryYearsMap = <ExamCategory, Set<int>>{};

    for (final q in questions) {
      _byCategory.putIfAbsent(q.examType, () => []).add(q);
      categorySubjectsMap.putIfAbsent(q.examType, () => {}).add(q.subject);
      categoryYearsMap.putIfAbsent(q.examType, () => {}).add(q.year);
    }

    categorySubjectsMap.forEach((category, subjects) {
      final list = subjects.toList()..sort();
      _subjectsByCategory[category] = list;
    });

    categoryYearsMap.forEach((category, years) {
      final list = years.toList()..sort((a, b) => b.compareTo(a));
      _yearsByCategory[category] = list;
    });
  }

  @override
  Future<List<PastQuestionModel>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
    int limit = 100,
  }) async {
    if (_cachedQuestions == null) {
      await initialize();
    }

    final candidates = examCategory != null
        ? (_byCategory[examCategory] ?? const <PastQuestionModel>[])
        : (_cachedQuestions ?? const <PastQuestionModel>[]);

    final normalizedSubject = subject?.trim().toLowerCase();
    final normalizedQuery = searchQuery?.trim().toLowerCase();
    final hasSubjectFilter =
        normalizedSubject != null &&
        normalizedSubject.isNotEmpty &&
        normalizedSubject != 'all';
    final hasQueryFilter =
        normalizedQuery != null && normalizedQuery.isNotEmpty;

    final filtered = candidates.where((q) {
      if (hasSubjectFilter) {
        final itemSubject = q.subject.toLowerCase();
        if (itemSubject != normalizedSubject &&
            !itemSubject.contains(normalizedSubject)) {
          return false;
        }
      }

      if (year != null && q.year != year) {
        return false;
      }

      if (hasQueryFilter) {
        final matchesPrompt = q.prompt.toLowerCase().contains(normalizedQuery);
        final matchesTopic = q.topic.toLowerCase().contains(normalizedQuery);
        final matchesSubject =
            q.subject.toLowerCase().contains(normalizedQuery);

        if (!matchesPrompt && !matchesTopic && !matchesSubject) {
          return false;
        }
      }

      return true;
    });

    if (limit > 0) {
      return filtered.take(limit).toList();
    }
    return filtered.toList();
  }

  @override
  Future<List<String>> getAvailableSubjects(ExamCategory category) async {
    if (_cachedQuestions == null) {
      await initialize();
    }
    return _subjectsByCategory[category] ??
        const [
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
    if (_cachedQuestions == null) {
      await initialize();
    }
    return _yearsByCategory[category] ??
        const [2024, 2023, 2022, 2021, 2020, 2019, 1999];
  }
}
