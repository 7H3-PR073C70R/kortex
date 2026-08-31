import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';

abstract class CalibrationRepository {
  Future<Either<Failure, void>> saveCalibrationProfile(
    CalibrationProfile profile,
  );

  Future<Either<Failure, CalibrationProfile?>> getCalibrationProfile();
}
