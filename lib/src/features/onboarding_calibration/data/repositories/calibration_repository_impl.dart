import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
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
  ) {
    return _localDataSource
        .saveCalibrationProfile(CalibrationProfileModel.fromEntity(profile))
        .makeRequest();
  }

  @override
  Future<Either<Failure, CalibrationProfile?>> getCalibrationProfile() {
    return _localDataSource
        .getCalibrationProfile()
        .then((model) => model?.toEntity())
        .makeRequest();
  }
}
