import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';

class GetCalibrationProfileUseCase
    with UseCase<CalibrationProfile?, NoParams> {
  const GetCalibrationProfileUseCase(this._repository);

  final CalibrationRepository _repository;

  @override
  Future<Either<Failure, CalibrationProfile?>> call(NoParams params) {
    return _repository.getCalibrationProfile();
  }
}
