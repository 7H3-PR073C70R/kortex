import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';

class SaveCalibrationProfileUseCase
    with UseCase<void, CalibrationProfile> {
  const SaveCalibrationProfileUseCase(this._repository);

  final CalibrationRepository _repository;

  @override
  Future<Either<Failure, void>> call(CalibrationProfile params) {
    return _repository.saveCalibrationProfile(params);
  }
}
