import 'dart:async';
import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_local_data_source.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';

class PastQuestionsRepositoryImpl implements PastQuestionsRepository {
  PastQuestionsRepositoryImpl(
    this._remoteDataSource, {
    PastQuestionsLocalDataSource? localDataSource,
    LocalStorageService? localStorageService,
  })  : _localDataSource = localDataSource,
        _localStorageService = localStorageService {
    _loadBookmarkedIds();
    unawaited(_effectiveLocalDataSource.initialize());
  }

  final PastQuestionsRemoteDataSource _remoteDataSource;
  final PastQuestionsLocalDataSource? _localDataSource;
  final LocalStorageService? _localStorageService;
  final Set<String> _bookmarkedIds = {};

  PastQuestionsLocalDataSource? _fallbackLocalDataSource;

  PastQuestionsLocalDataSource get _effectiveLocalDataSource =>
      _localDataSource ??
      (locator.isRegistered<PastQuestionsLocalDataSource>()
          ? locator<PastQuestionsLocalDataSource>()
          : (_fallbackLocalDataSource ??= PastQuestionsLocalDataSourceImpl()));

  LocalStorageService? get _effectiveLocalStorage =>
      _localStorageService ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : null);

  void _loadBookmarkedIds() {
    try {
      final storage = _effectiveLocalStorage;
      final raw = storage?.getPreference(key: PrefKeys.pastQuestionBookmarks);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _bookmarkedIds.addAll(decoded.map((e) => e.toString()));
        }
      }
    } on Object catch (_) {}
  }

  Future<void> _persistBookmarkedIds() async {
    try {
      final storage = _effectiveLocalStorage;
      if (storage != null) {
        await storage.savePreference(
          key: PrefKeys.pastQuestionBookmarks,
          data: jsonEncode(_bookmarkedIds.toList()),
        );
      }
    } on Object catch (_) {}
  }

  @override
  Future<Either<Failure, List<PastQuestionEntity>>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
    String? courseId,
    String? courseCode,
  }) {
    return Future<List<PastQuestionEntity>>.sync(() async {
      // 1. Fetch remote data from Supabase actively
      var remote = <PastQuestionModel>[];
      try {
        remote = await _remoteDataSource.getPastQuestions(
          examCategory: examCategory,
          subject: subject,
          year: year,
          searchQuery: searchQuery,
          courseId: courseId,
          courseCode: courseCode,
        );

        if (remote.isNotEmpty) {
          // Write-through caching to local SQLite database so subsequent queries work offline
          unawaited(_effectiveLocalDataSource.savePastQuestions(remote));
        }
      } on Object catch (_) {}

      // 2. Fetch local offline/cached questions
      var local = <PastQuestionModel>[];
      try {
        local = await _effectiveLocalDataSource.getPastQuestions(
          examCategory: examCategory,
          subject: subject,
          year: year,
          searchQuery: searchQuery,
          courseId: courseId,
          courseCode: courseCode,
        );
      } on Object catch (_) {}

      // 3. Merge results, preferring remote/updated items
      final seenIds = <String>{};
      final merged = <PastQuestionModel>[];

      for (final q in remote) {
        if (seenIds.add(q.id)) {
          merged.add(q);
        }
      }
      for (final q in local) {
        if (seenIds.add(q.id)) {
          merged.add(q);
        }
      }

      return merged.map((m) {
        final entity = m.toEntity();
        if (_bookmarkedIds.contains(entity.id)) {
          return entity.copyWith(isBookmarked: true);
        }
        return entity;
      }).toList();
    }).makeRequest();
  }

  @override
  Future<Either<Failure, List<String>>> getAvailableSubjects(
    ExamCategory category,
  ) {
    return Future<List<String>>.sync(() async {
      try {
        final local =
            await _effectiveLocalDataSource.getAvailableSubjects(category);
        if (local.isNotEmpty) return local;
      } on Object catch (_) {}
      return _remoteDataSource.getAvailableSubjects(category);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, List<int>>> getAvailableYears(
    ExamCategory category,
  ) {
    return Future<List<int>>.sync(() async {
      try {
        final local =
            await _effectiveLocalDataSource.getAvailableYears(category);
        if (local.isNotEmpty) return local;
      } on Object catch (_) {}
      return _remoteDataSource.getAvailableYears(category);
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> toggleBookmarkQuestion(
    String questionId,
  ) {
    return Future<void>.sync(() async {
      if (_bookmarkedIds.contains(questionId)) {
        _bookmarkedIds.remove(questionId);
      } else {
        _bookmarkedIds.add(questionId);
      }
      await _persistBookmarkedIds();
    }).makeRequest();
  }

  @override
  Future<Either<Failure, void>> savePastQuestions(
    List<PastQuestionEntity> questions,
  ) {
    final models = questions.map((e) {
      return PastQuestionModel(
        id: e.id,
        examType: e.examType,
        subject: e.subject,
        year: e.year,
        questionNumber: e.questionNumber,
        prompt: e.prompt,
        options: e.options,
        correctOptionIndex: e.correctOptionIndex,
        correctOptionLabel: e.correctOptionLabel,
        explanation: e.explanation,
        topic: e.topic,
        passage: e.passage,
        latexFormula: e.latexFormula,
        imageUrl: e.imageUrl,
        difficulty: e.difficulty,
        isUserAdded: e.isUserAdded,
        courseId: e.courseId,
        courseCode: e.courseCode,
      );
    }).toList();

    return Future<void>.sync(() async {
      // 1. Save to local data source
      try {
        await _effectiveLocalDataSource.savePastQuestions(models);
      } on Object catch (_) {}

      // 2. Sync to remote data source
      try {
        await _remoteDataSource.savePastQuestions(models);
      } on Object catch (_) {}
    }).makeRequest();
  }
}
