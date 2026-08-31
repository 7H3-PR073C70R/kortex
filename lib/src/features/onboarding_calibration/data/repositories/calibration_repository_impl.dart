import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_local_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';

class CalibrationRepositoryImpl implements CalibrationRepository {
  const CalibrationRepositoryImpl({
    required CalibrationLocalDataSource localDataSource,
  }) : _localDataSource = localDataSource;

  final CalibrationLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, void>> saveCalibrationProfile(
    CalibrationProfile profile,
  ) async {
    try {
      final model = CalibrationProfileModel.fromEntity(profile);
      await _localDataSource.saveCalibrationProfile(model);
      return const Right(null);
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, CalibrationProfile?>> getCalibrationProfile() async {
    try {
      final model = await _localDataSource.getCalibrationProfile();
      return Right(model?.toEntity());
    } on Object catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
