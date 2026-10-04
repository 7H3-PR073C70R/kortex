import 'package:kortex/src/features/force_update/data/client/app_version_api_client.dart';
import 'package:kortex/src/features/force_update/data/data_sources/app_version_remote_data_source.dart';
import 'package:kortex/src/features/force_update/data/models/app_version_model.dart';
import 'package:kortex/src/features/force_update/domain/entities/app_version_entity.dart';

class AppVersionRemoteDataSourceImpl implements AppVersionRemoteDataSource {
  const AppVersionRemoteDataSourceImpl({
    required AppVersionApiClient apiClient,
  }) : _apiClient = apiClient;

  final AppVersionApiClient _apiClient;

  @override
  Future<AppVersionEntity> fetchVersionConfig(String platform) async {
    final res = await _apiClient.fetchVersionConfig({
      'platform': 'eq.$platform',
      'is_force_update_active': 'eq.true',
      'select': '*',
      'limit': '1',
      'order': 'updated_at.desc',
    });

    final rawData = res.data;
    if (rawData is List && rawData.isNotEmpty) {
      return AppVersionModel.fromJson(rawData.first as Map<String, dynamic>);
    }

    // Graceful fallback: treat as no active force-update so users are never
    // locked out by a misconfigured / empty table.
    return AppVersionModel(
      platform: platform,
      minimumVersion: '0.0.0',
      currentVersion: '0.0.0',
      isForceUpdateActive: false,
      storeUrl: '',
    );
  }
}
