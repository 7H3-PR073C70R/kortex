import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';

abstract class CalibrationRemoteDataSource {
  Future<void> syncCalibrationProfile(CalibrationProfileModel profile);
  Future<CalibrationProfileModel?> fetchCalibrationProfile();
}
