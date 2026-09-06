import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/di/locator.dart';
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
    AppDatabase? appDatabase,
  })  : _assetBundle = assetBundle ?? rootBundle,
        _assetPath = assetPath,
        _appDatabase = appDatabase ??
            (locator.isRegistered<AppDatabase>()
                ? locator<AppDatabase>()
                : null);

  final AssetBundle _assetBundle;
  final String _assetPath;
  final AppDatabase? _appDatabase;

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

        // Seed to SQLite Drift database if empty
        if (_appDatabase != null) {
          try {
            final count = await _appDatabase.countPastQuestions();
            if (count == 0) {
              final companions = parsed.map(_modelToCompanion).toList();
              await _appDatabase.batchInsertPastQuestions(companions);
            }
          } on Object {
            // Ignore if DB is closed or testing without DB
          }
        }
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

    // High-performance Drift query with SQLite FTS5 if database is available
    if (_appDatabase != null) {
      try {
        final entries = await _appDatabase.getPastQuestionsList(
          examType: examCategory?.code,
          subject: subject,
          year: year,
          searchQuery: searchQuery,
          limit: limit,
        );
        if (entries.isNotEmpty) {
          return entries.map(_entryToModel).toList();
        }
      } on Object {
        // Fallback to in-memory filter
      }
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
    if (_appDatabase != null) {
      try {
        final dbSubjects =
            await _appDatabase.getAvailableSubjectsForExam(category.code);
        if (dbSubjects.isNotEmpty) return dbSubjects;
      } on Object {
        // Fallback
      }
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
    if (_appDatabase != null) {
      try {
        final dbYears =
            await _appDatabase.getAvailableYearsForExam(category.code);
        if (dbYears.isNotEmpty) return dbYears;
      } on Object {
        // Fallback
      }
    }
    return _yearsByCategory[category] ??
        const [2024, 2023, 2022, 2021, 2020, 2019, 1999];
  }

  // --- Drift Helpers ---

  PastQuestionsCompanion _modelToCompanion(PastQuestionModel model) {
    return PastQuestionsCompanion(
      id: Value(model.id),
      examType: Value(model.examType.code),
      subject: Value(model.subject),
      year: Value(model.year),
      questionNumber: Value(model.questionNumber),
      prompt: Value(model.prompt),
      optionsJson: Value(jsonEncode(model.options)),
      correctOptionIndex: Value(model.correctOptionIndex),
      correctOptionLabel: Value(model.correctOptionLabel),
      explanation: Value(model.explanation),
      topic: Value(model.topic),
      passage: Value(model.passage),
      latexFormula: Value(model.latexFormula),
      imageUrl: Value(model.imageUrl),
      difficulty: Value(model.difficulty),
    );
  }

  PastQuestionModel _entryToModel(PastQuestionEntry entry) {
    ExamCategory category;
    final rawExam = entry.examType.toLowerCase();
    if (rawExam.contains('waec') || rawExam.contains('wassce')) {
      category = ExamCategory.waec;
    } else if (rawExam.contains('jamb') || rawExam.contains('utme')) {
      category = ExamCategory.jamb;
    } else if (rawExam.contains('neco')) {
      category = ExamCategory.neco;
    } else if (rawExam.contains('sat')) {
      category = ExamCategory.sat;
    } else if (rawExam.contains('toefl')) {
      category = ExamCategory.toefl;
    } else if (rawExam.contains('ielts')) {
      category = ExamCategory.ielts;
    } else if (rawExam.contains('med')) {
      category = ExamCategory.medicine;
    } else if (rawExam.contains('law')) {
      category = ExamCategory.law;
    } else if (rawExam.contains('eng')) {
      category = ExamCategory.engineering;
    } else if (rawExam.contains('bus') || rawExam.contains('acc')) {
      category = ExamCategory.business;
    } else if (rawExam.contains('cs') || rawExam.contains('comp')) {
      category = ExamCategory.computerScience;
    } else {
      category = ExamCategory.general;
    }

    var optionsList = <String>[];
    try {
      final dynamic decoded = jsonDecode(entry.optionsJson);
      if (decoded is List) {
        optionsList = decoded.map((e) => e.toString()).toList();
      }
    } on Object {
      // Fallback
    }

    return PastQuestionModel(
      id: entry.id,
      examType: category,
      subject: entry.subject,
      year: entry.year,
      questionNumber: entry.questionNumber,
      prompt: entry.prompt,
      options: optionsList,
      correctOptionIndex: entry.correctOptionIndex,
      correctOptionLabel: entry.correctOptionLabel,
      explanation: entry.explanation,
      topic: entry.topic,
      passage: entry.passage,
      latexFormula: entry.latexFormula,
      imageUrl: entry.imageUrl,
      difficulty: entry.difficulty,
    );
  }
}
