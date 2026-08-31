import 'package:kortex/src/core/error/exceptions.dart';
import 'package:kortex/src/core/error/failure.dart';
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
  Future<Either<Failure, DashboardFeedEntity>> getDashboardFeed() async {
    try {
      final feedModel = await remoteDataSource.getDashboardFeed();

      // Retrieve user calibration profile to customize dashboard layout
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

      final feedEntity = feedModel.toEntity(calibrationProfile: userProfile);
      return Right(feedEntity);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StudyDeckEntity>>> getSm2ReviewQueue() async {
    try {
      final deckModels = await remoteDataSource.getReviewQueue();
      final deckEntities = deckModels.map((e) => e.toEntity()).toList();
      return Right(deckEntities);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> quickStartMockExam({
    required String examId,
    required String subject,
  }) async {
    try {
      final sessionId = await remoteDataSource.startMockExam(
        examId: examId,
        subject: subject,
      );
      return Right(sessionId);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
