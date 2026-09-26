import 'dart:async';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/crashlytics_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/onboarding_calibration/data/data_sources/curriculum_remote_data_source.dart';
import 'package:kortex/src/features/onboarding_calibration/data/models/curriculum_metadata_model.dart';

class CurriculumRemoteDataSourceImpl implements CurriculumRemoteDataSource {
  CurriculumRemoteDataSourceImpl(this._dio, {CrashlyticsService? crashlytics})
    : _crashlyticsOverride = crashlytics;

  final Dio _dio;
  final CrashlyticsService? _crashlyticsOverride;

  CrashlyticsService? get _crashlyticsService {
    if (_crashlyticsOverride != null) return _crashlyticsOverride;
    try {
      return locator<CrashlyticsService>();
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<List<CurriculumMetadataModel>> fetchMetadataByCategory(
    String category,
  ) async {
    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.curriculumMetadata}?category=eq.$category';
      final response = await _dio.get<dynamic>(
        endpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 && response.data is List) {
        final rawList = response.data as List<dynamic>;
        return rawList
            .map(
              (item) => CurriculumMetadataModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
      return const [];
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'CurriculumRemoteDataSource.fetchMetadataByCategory failed for $category',
          ),
        );
      }
      return const [];
    }
  }

  @override
  Future<List<CurriculumMetadataModel>> fetchAllMetadata() async {
    try {
      final endpoint =
          '${AppApiEndpoint.baseUri}${AppApiEndpoint.curriculumMetadata}';
      final response = await _dio.get<dynamic>(
        endpoint,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      if (response.statusCode == 200 && response.data is List) {
        final rawList = response.data as List<dynamic>;
        return rawList
            .map(
              (item) => CurriculumMetadataModel.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
      }
      return const [];
    } on Object catch (e, stack) {
      final crashlytics = _crashlyticsService;
      if (crashlytics != null) {
        unawaited(
          crashlytics.recordError(
            e,
            stack,
            reason:
                'CurriculumRemoteDataSource.fetchAllMetadata failed',
          ),
        );
      }
      return const [];
    }
  }
}
