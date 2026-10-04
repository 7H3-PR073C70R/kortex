import 'package:kortex/src/features/force_update/data/data_sources/app_version_remote_data_source.dart';
import 'package:kortex/src/features/force_update/domain/entities/app_version_entity.dart';
import 'package:kortex/src/features/force_update/domain/repositories/app_version_repository.dart';

class AppVersionRepositoryImpl implements AppVersionRepository {
  const AppVersionRepositoryImpl({
    required AppVersionRemoteDataSource remoteDataSource,
  }) : _remote = remoteDataSource;

  final AppVersionRemoteDataSource _remote;

  @override
  Future<AppVersionEntity> fetchVersionConfig(String platform) =>
      _remote.fetchVersionConfig(platform);
}
