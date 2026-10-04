import 'package:kortex/src/features/force_update/domain/entities/app_version_entity.dart';

abstract interface class AppVersionRemoteDataSource {
  Future<AppVersionEntity> fetchVersionConfig(String platform);
}
