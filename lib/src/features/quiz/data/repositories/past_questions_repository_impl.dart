import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/data/models/past_question_model.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';

class PastQuestionsRepositoryImpl implements PastQuestionsRepository {
  PastQuestionsRepositoryImpl(
    this._remoteDataSource, {
    LocalStorageService? localStorageService,
  }) : _localStorageService = localStorageService {
    _loadBookmarkedIds();
  }

  final PastQuestionsRemoteDataSource _remoteDataSource;
  final LocalStorageService? _localStorageService;
  final Set<String> _bookmarkedIds = {};

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
  }) {
    return _remoteDataSource
        .getPastQuestions(
          examCategory: examCategory,
          subject: subject,
          year: year,
          searchQuery: searchQuery,
        )
        .then((models) {
          return models.map((m) {
            final entity = m.toEntity();
            if (_bookmarkedIds.contains(entity.id)) {
              return entity.copyWith(isBookmarked: true);
            }
            return entity;
          }).toList();
        })
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<String>>> getAvailableSubjects(
    ExamCategory category,
  ) {
    return _remoteDataSource.getAvailableSubjects(category).makeRequest();
  }

  @override
  Future<Either<Failure, List<int>>> getAvailableYears(
    ExamCategory category,
  ) {
    return _remoteDataSource.getAvailableYears(category).makeRequest();
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
      );
    }).toList();

    return _remoteDataSource.savePastQuestions(models).makeRequest();
  }
}
