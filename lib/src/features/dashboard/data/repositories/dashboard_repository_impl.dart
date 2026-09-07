import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/dashboard/data/data_sources/dashboard_remote_data_source.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required this.remoteDataSource,
    required this.calibrationRepository,
    this.feedTtl = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DashboardRemoteDataSource remoteDataSource;
  final CalibrationRepository calibrationRepository;
  final Duration feedTtl;
  final DateTime Function() _clock;

  DashboardFeedEntity? _cachedFeed;
  DateTime? _feedCachedAt;

  @override
  void clearFeedCache() {
    _cachedFeed = null;
    _feedCachedAt = null;
  }

  @override
  Future<Either<Failure, DashboardFeedEntity>> getDashboardFeed({
    bool forceRefresh = false,
  }) async {
    final now = _clock();
    if (!forceRefresh &&
        _cachedFeed != null &&
        _feedCachedAt != null &&
        now.difference(_feedCachedAt!) < feedTtl) {
      return Right(_cachedFeed!);
    }

    final result = await (() async {
      final feedModel = await remoteDataSource.getDashboardFeed();
      var userProfile = const CalibrationProfile();

      final profileResult = await calibrationRepository.getCalibrationProfile();
      profileResult.fold(
        (_) {},
        (profile) {
          if (profile != null) {
            userProfile = profile;
          }
        },
      );

      return feedModel.toEntity(calibrationProfile: userProfile);
    })().makeRequest();

    return result.fold(
      Left.new,
      (feed) {
        _cachedFeed = feed;
        _feedCachedAt = now;
        return Right(feed);
      },
    );
  }

  @override
  Future<Either<Failure, List<StudyDeckEntity>>> getReviewQueue() {
    return remoteDataSource
        .getReviewQueue()
        .then((deckModels) => deckModels.map((e) => e.toEntity()).toList())
        .makeRequest();
  }


  @override
  Future<Either<Failure, String>> quickStartMockExam({
    required String examId,
    required String subject,
  }) {
    return remoteDataSource
        .startMockExam(
          examId: examId,
          subject: subject,
        )
        .makeRequest();
  }

  @override
  Future<Either<Failure, List<CuratedCourseEntity>>> getCatalogCourses() {
    return remoteDataSource
        .getCatalogCourses()
        .then((models) => models.map((e) => e.toEntity()).toList())
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> syncUserCourses(
    List<Map<String, dynamic>> courses,
  ) {
    clearFeedCache();
    return remoteDataSource.syncUserCourses(courses).makeRequest();
  }

  @override
  Future<Either<Failure, void>> autoCurateExamCourses({
    required String examName,
    required List<String> subjects,
  }) {
    clearFeedCache();
    return remoteDataSource
        .autoCurateExamCourses(
          examName: examName,
          subjects: subjects,
        )
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteCuratedCourse(String courseId) {
    clearFeedCache();
    return remoteDataSource.deleteCuratedCourse(courseId).makeRequest();
  }

  @override
  Future<Either<Failure, List<CuratedCourseEntity>>> getUserCuratedCourses() {
    return remoteDataSource
        .getUserCuratedCourses()
        .then((models) => models.map((e) => e.toEntity()).toList())
        .makeRequest();
  }
}
