import 'package:kortex/src/features/force_update/domain/entities/app_version_entity.dart';

abstract interface class AppVersionRepository {
  /// Fetches the version config for [platform] ("ios" | "android").
  ///
  /// Throws on network failure.
  Future<AppVersionEntity> fetchVersionConfig(String platform);
}
