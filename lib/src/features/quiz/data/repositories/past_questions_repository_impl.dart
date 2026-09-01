import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/services/past_questions_crawler_service.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';

class PastQuestionsRepositoryImpl implements PastQuestionsRepository {
  PastQuestionsRepositoryImpl(this._crawlerService);

  final PastQuestionsCrawlerService _crawlerService;
  final Set<String> _bookmarkedIds = {};

  @override
  Future<Either<Failure, List<PastQuestionEntity>>> getPastQuestions({
    ExamCategory? examCategory,
    String? subject,
    int? year,
    String? searchQuery,
  }) async {
    try {
      if (!_crawlerService.isCrawlingCompleted) {
        await _crawlerService.crawlAllPastQuestions();
      }

      final models = _crawlerService.queryQuestions(
        examCategory: examCategory,
        subject: subject,
        year: year,
        searchQuery: searchQuery,
      );

      final entities = models.map((m) {
        final entity = m.toEntity();
        if (_bookmarkedIds.contains(entity.id)) {
          return entity.copyWith(isBookmarked: true);
        }
        return entity;
      }).toList();

      return Right(entities);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAvailableSubjects(
    ExamCategory category,
  ) async {
    try {
      if (!_crawlerService.isCrawlingCompleted) {
        await _crawlerService.crawlAllPastQuestions();
      }

      final models = _crawlerService.queryQuestions(examCategory: category);
      final subjects = models.map((m) => m.subject).toSet().toList()..sort();
      return Right(subjects);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<int>>> getAvailableYears(
    ExamCategory category,
  ) async {
    try {
      if (!_crawlerService.isCrawlingCompleted) {
        await _crawlerService.crawlAllPastQuestions();
      }

      final models = _crawlerService.queryQuestions(examCategory: category);
      final years = models.map((m) => m.year).toSet().toList()
        ..sort((a, b) => b.compareTo(a)); // Descending order
      return Right(years);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleBookmarkQuestion(
    String questionId,
  ) async {
    try {
      if (_bookmarkedIds.contains(questionId)) {
        _bookmarkedIds.remove(questionId);
      } else {
        _bookmarkedIds.add(questionId);
      }
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
