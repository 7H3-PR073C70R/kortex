import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/quiz/data/data_sources/past_questions_remote_data_source.dart';
import 'package:kortex/src/features/quiz/domain/entities/past_question_entity.dart';
import 'package:kortex/src/features/quiz/domain/repositories/past_questions_repository.dart';

class PastQuestionsRepositoryImpl implements PastQuestionsRepository {
  PastQuestionsRepositoryImpl(this._remoteDataSource);

  final PastQuestionsRemoteDataSource _remoteDataSource;
  final Set<String> _bookmarkedIds = {};

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
    }).makeRequest();
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
    return Future<void>.sync(() {
      if (_bookmarkedIds.contains(questionId)) {
        _bookmarkedIds.remove(questionId);
      } else {
        _bookmarkedIds.add(questionId);
      }
    }).makeRequest();
  }
}
