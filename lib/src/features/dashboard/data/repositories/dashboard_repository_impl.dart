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
  const DashboardRepositoryImpl({
    required this.remoteDataSource,
    required this.calibrationRepository,
  });

  final DashboardRemoteDataSource remoteDataSource;
  final CalibrationRepository calibrationRepository;

  @override
  Future<Either<Failure, DashboardFeedEntity>> getDashboardFeed() {
    return remoteDataSource.getDashboardFeed().then((feedModel) async {
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
    }).makeRequest();
  }

  @override
  Future<Either<Failure, List<StudyDeckEntity>>> getSm2ReviewQueue() {
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
    return remoteDataSource.syncUserCourses(courses).makeRequest();
  }

  @override
  Future<Either<Failure, void>> autoCurateExamCourses({
    required String examName,
    required List<String> subjects,
  }) {
    return remoteDataSource
        .autoCurateExamCourses(
          examName: examName,
          subjects: subjects,
        )
        .makeRequest();
  }
}
