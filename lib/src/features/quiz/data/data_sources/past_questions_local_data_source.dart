import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
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
    String? courseId,
    String? courseCode,
    int limit = 100,
  });

  Future<List<String>> getAvailableSubjects(ExamCategory category);

  Future<List<int>> getAvailableYears(ExamCategory category);

  Future<void> savePastQuestions(List<PastQuestionModel> questions);
}

class PastQuestionsLocalDataSourceImpl implements PastQuestionsLocalDataSource {
  PastQuestionsLocalDataSourceImpl({
    AppDatabase? appDatabase,
    LocalStorageService? localStorageService,
    List<PastQuestionModel>? initialQuestions,
  })  : _appDatabase = appDatabase ??
            (locator.isRegistered<AppDatabase>()
                ? locator<AppDatabase>()
                : null),
        _localStorageService = localStorageService ??
            (locator.isRegistered<LocalStorageService>()
                ? locator<LocalStorageService>()
                : null),
        _seedQuestions = initialQuestions;

  final AppDatabase? _appDatabase;
  final LocalStorageService? _localStorageService;
  final List<PastQuestionModel>? _seedQuestions;

  List<PastQuestionModel>? _cachedQuestions;
  final List<PastQuestionModel> _userAddedQuestions = [];
  final Map<ExamCategory, List<PastQuestionModel>> _byCategory = {};
  final Map<ExamCategory, List<String>> _subjectsByCategory = {};
  final Map<ExamCategory, List<int>> _yearsByCategory = {};

  @override
  bool get isInitialized => _cachedQuestions != null;

  @override
  Future<void> initialize() async {
    if (_cachedQuestions != null) return;

    final allQuestions = <PastQuestionModel>[];

    // Purge any legacy mock questions from local SQLite database
    if (_appDatabase != null) {
      try {
        await _appDatabase.deleteMockPastQuestions();
        final dbEntries = await _appDatabase.getPastQuestionsList(limit: 0);
        allQuestions.addAll(dbEntries.map(_entryToModel));
      } on Object catch (_) {
        // Database unavailable or query failed; fallback to local memory cache.
      }
    }

    // Injected seed questions (e.g. for testing)
    if (_seedQuestions != null && _seedQuestions.isNotEmpty) {
      for (final q in _seedQuestions) {
        if (!allQuestions.any((item) => item.id == q.id)) {
          allQuestions.add(q);
        }
      }
    }

    // Load persisted user-added past questions
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      final raw = storage?.getPreference(key: PrefKeys.userAddedPastQuestions);
      if (raw != null && raw.trim().isNotEmpty) {
        final dynamic decodedUser = jsonDecode(raw);
        if (decodedUser is List) {
          final userParsed = decodedUser
              .whereType<Map<String, dynamic>>()
              .map(PastQuestionModel.fromJson)
              .toList();
          _userAddedQuestions
            ..clear()
            ..addAll(userParsed);
          for (final uq in userParsed) {
            if (!allQuestions.any((item) => item.id == uq.id)) {
              allQuestions.insert(0, uq);
            }
          }
        }
      }
    } on Object catch (_) {
      // Preference storage parsing failed; proceed with base questions.
    }

    _cachedQuestions = allQuestions;
    _buildIndices(allQuestions);
  }

  @override
  Future<void> savePastQuestions(List<PastQuestionModel> questions) async {
    if (questions.isEmpty) return;
    if (_cachedQuestions == null) {
      await initialize();
    }

    final newQuestions = questions.map((q) {
      return PastQuestionModel(
        id: q.id,
        examType: q.examType,
        subject: q.subject,
        year: q.year,
        questionNumber: q.questionNumber,
        prompt: q.prompt,
        options: q.options,
        correctOptionIndex: q.correctOptionIndex,
        correctOptionLabel: q.correctOptionLabel,
        explanation: q.explanation,
        topic: q.topic,
        passage: q.passage,
        latexFormula: q.latexFormula,
        imageUrl: q.imageUrl,
        difficulty: q.difficulty,
        isUserAdded: true,
        courseId: q.courseId,
        courseCode: q.courseCode,
      );
    }).toList();

    // Prevent duplicates by ID
    final existingIds = _userAddedQuestions.map((q) => q.id).toSet();
    for (final q in newQuestions) {
      if (!existingIds.contains(q.id)) {
        _userAddedQuestions.insert(0, q);
        _cachedQuestions?.insert(0, q);
        existingIds.add(q.id);
      }
    }

    _buildIndices(_cachedQuestions ?? _userAddedQuestions);

    // Persist to LocalStorageService
    try {
      final storage = _localStorageService ??
          (locator.isRegistered<LocalStorageService>()
              ? locator<LocalStorageService>()
              : null);
      if (storage != null) {
        final payload = jsonEncode(
          _userAddedQuestions.map((q) => q.toJson()).toList(),
        );
        await storage.savePreference(
          key: PrefKeys.userAddedPastQuestions,
          data: payload,
        );
      }
    } on Object catch (_) {
      // Local storage write failed.
    }

    // Optionally insert to AppDatabase if available
    if (_appDatabase != null) {
      try {
        final companions = newQuestions.map(_modelToCompanion).toList();
        await _appDatabase.batchInsertPastQuestions(companions);
      } on Object catch (_) {
        // SQLite batch insertion failed.
      }
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
    String? courseId,
    String? courseCode,
    int limit = 100,
  }) async {
    if (_cachedQuestions == null) {
      await initialize();
    }

    final allList = _cachedQuestions ?? const <PastQuestionModel>[];
    final cleanCode = courseCode?.trim().toLowerCase();

    // If courseId or courseCode is specified, find matching questions
    final candidates = allList.where((q) {
      final matchCourse = (courseId != null && q.courseId == courseId) ||
          (cleanCode != null &&
              q.courseCode != null &&
              q.courseCode!.trim().toLowerCase() == cleanCode);
      if (matchCourse) return true;

      if (examCategory != null && q.examType != examCategory) {
        return false;
      }
      return true;
    }).toList();

    final normalizedSubject = subject?.trim().toLowerCase();
    final normalizedQuery = searchQuery?.trim().toLowerCase();
    final hasSubjectFilter =
        normalizedSubject != null &&
        normalizedSubject.isNotEmpty &&
        normalizedSubject != 'all';
    final hasQueryFilter =
        normalizedQuery != null && normalizedQuery.isNotEmpty;

    final filtered = candidates.where((q) {
      final isExactCourseMatch = (courseId != null && q.courseId == courseId) ||
          (cleanCode != null &&
              q.courseCode != null &&
              q.courseCode!.trim().toLowerCase() == cleanCode);

      if (!isExactCourseMatch && hasSubjectFilter) {
        final itemSubject = q.subject.toLowerCase();
        if (itemSubject != normalizedSubject &&
            !itemSubject.contains(normalizedSubject) &&
            !normalizedSubject.contains(itemSubject)) {
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
      } on Object catch (_) {
        // AppDatabase query failed; fallback to in-memory index.
      }
    }
    return _subjectsByCategory[category] ?? const [];
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
      } on Object catch (_) {
        // AppDatabase query failed; fallback to in-memory index.
      }
    }
    return _yearsByCategory[category] ?? const [];
  }

  // --- Drift Helpers ---

  PastQuestionModel _entryToModel(PastQuestionEntry entry) {
    var options = <String>[];
    try {
      final decoded = jsonDecode(entry.optionsJson);
      if (decoded is List) {
        options = decoded.map((e) => e.toString()).toList();
      }
    } on Object catch (_) {
      // Options parsing failed; options defaults to empty list.
    }
    return PastQuestionModel(
      id: entry.id,
      examType: PastQuestionModel.parseExamCategory(entry.examType),
      subject: entry.subject,
      year: entry.year,
      questionNumber: entry.questionNumber,
      prompt: entry.prompt,
      options: options,
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
}
