import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/calibration_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/calibration_profile_model.dart';

class CalibrationRemoteDataSourceImpl implements CalibrationRemoteDataSource {
  CalibrationRemoteDataSourceImpl(
    this._dio, {
    UserStorageService? userStorageService,
    CrashlyticsService? crashlytics,
  })  : _userStorageServiceOverride = userStorageService,
        _crashlyticsOverride = crashlytics;

  final Dio _dio;
  final UserStorageService? _userStorageServiceOverride;
  final CrashlyticsService? _crashlyticsOverride;

  UserStorageService? get _userStorageService {
    if (_userStorageServiceOverride != null) return _userStorageServiceOverride;
    try {
      return locator<UserStorageService>();
    } on Object catch (_) {
      return null;
    }
  }

  CrashlyticsService? get _crashlyticsService {
    if (_crashlyticsOverride != null) return _crashlyticsOverride;
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> syncCalibrationProfile(CalibrationProfileModel profile) async {
    final userId = _userStorageService?.getUserId();
    if (userId == null || userId.isEmpty) return;

    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.userCalibrations}?on_conflict=user_id';
      final payload = _toRemoteJson(profile, userId);

      await _dio.post<dynamic>(
        endpoint,
        data: payload,
        options: Options(
          headers: const {
            'Prefer': 'resolution=merge-duplicates,return=representation',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason: 'CalibrationRemoteDataSource.syncCalibrationProfile failed',
          ),
        );
      }
    }
  }

  @override
  Future<CalibrationProfileModel?> fetchCalibrationProfile() async {
    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.userCalibrations}?select=*&limit=1';
      final response = await _dio.get<dynamic>(
        endpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List<dynamic>;
        if (list.isNotEmpty && list.first is Map<String, dynamic>) {
          return _fromRemoteJson(list.first as Map<String, dynamic>);
        }
      }
      return null;
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason: 'CalibrationRemoteDataSource.fetchCalibrationProfile failed',
          ),
        );
      }
      return null;
    }
  }

  Map<String, dynamic> _toRemoteJson(
    CalibrationProfileModel profile,
    String userId,
  ) {
    return {
      'user_id': userId,
      'focus': profile.focus,
      'higher_ed_level': profile.higherEdLevel,
      'higher_ed_field': profile.higherEdField,
      'higher_ed_goals': profile.higherEdGoals,
      'high_school_exam': profile.highSchoolExam,
      'high_school_subjects': profile.highSchoolSubjects,
      'high_school_timeline': profile.highSchoolTimeline,
      'is_calibrated': profile.isCalibrated,
    };
  }

  CalibrationProfileModel _fromRemoteJson(Map<String, dynamic> json) {
    return CalibrationProfileModel(
      focus: (json['focus'] as String?)?.isNotEmpty == true
          ? json['focus'] as String
          : 'higherEducation',
      higherEdLevel:
          json['higher_ed_level'] as String? ?? json['higherEdLevel'] as String?,
      higherEdField:
          json['higher_ed_field'] as String? ?? json['higherEdField'] as String?,
      higherEdGoals: (json['higher_ed_goals'] as List<dynamic>? ??
              json['higherEdGoals'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
      highSchoolExam:
          json['high_school_exam'] as String? ?? json['highSchoolExam'] as String?,
      highSchoolSubjects: (json['high_school_subjects'] as List<dynamic>? ??
              json['highSchoolSubjects'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
      highSchoolTimeline: json['high_school_timeline'] as String? ??
          json['highSchoolTimeline'] as String?,
      isCalibrated:
          json['is_calibrated'] as bool? ?? json['isCalibrated'] as bool? ?? false,
    );
  }
}
