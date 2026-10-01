import 'dart:async';

import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_local_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';

class CalibrationRepositoryImpl implements CalibrationRepository {
  const CalibrationRepositoryImpl({
    required CalibrationLocalDataSource localDataSource,
    CalibrationRemoteDataSource? remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  final CalibrationLocalDataSource _localDataSource;
  final CalibrationRemoteDataSource? _remoteDataSource;

  @override
  Future<Either<Failure, void>> saveCalibrationProfile(
    CalibrationProfile profile,
  ) {
    final model = CalibrationProfileModel.fromEntity(profile);
    if (_remoteDataSource != null) {
      unawaited(_remoteDataSource.syncCalibrationProfile(model));
    }
    return _localDataSource.saveCalibrationProfile(model).makeRequest();
  }

  @override
  Future<Either<Failure, CalibrationProfile?>> getCalibrationProfile() {
    return Future<CalibrationProfile?>.sync(() async {
      final local = await _localDataSource.getCalibrationProfile();
      if (local != null) {
        return local.toEntity();
      }

      if (_remoteDataSource != null) {
        final remote = await _remoteDataSource.fetchCalibrationProfile();
        if (remote != null) {
          await _localDataSource.saveCalibrationProfile(remote);
          return remote.toEntity();
        }
      }

      return null;
    }).makeRequest();
  }
}
