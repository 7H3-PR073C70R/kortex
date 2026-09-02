import 'dart:convert';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';

abstract class CalibrationLocalDataSource {
  Future<void> saveCalibrationProfile(CalibrationProfileModel profile);
  Future<CalibrationProfileModel?> getCalibrationProfile();
}

class CalibrationLocalDataSourceImpl implements CalibrationLocalDataSource {
  const CalibrationLocalDataSourceImpl({
    required LocalStorageService storageService,
  }) : _storageService = storageService;

  final LocalStorageService _storageService;
  static const String _calibrationProfileKey = '__calibration_profile';

  @override
  Future<void> saveCalibrationProfile(CalibrationProfileModel profile) async {
    final jsonStr = jsonEncode(profile.toJson());
    await _storageService.savePreference(
      key: _calibrationProfileKey,
      data: jsonStr,
    );
    await _storageService.savePreference(
      key: PrefKeys.hasCompletedOnboarding,
      data: 'true',
    );
  }

  @override
  Future<CalibrationProfileModel?> getCalibrationProfile() async {
    final raw = _storageService.getPreference(key: _calibrationProfileKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return CalibrationProfileModel.fromJson(jsonMap);
    } on Exception catch (_) {
      return null;
    }
  }
}
