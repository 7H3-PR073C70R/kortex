part of 'locator.dart';

void _initRepositoryLocator() {
  locator
    ..registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remoteDataSource: locator<AuthRemoteDataSource>(),
        userStorageService: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<CalibrationRepository>(
      () => CalibrationRepositoryImpl(
        localDataSource: locator<CalibrationLocalDataSource>(),
      ),
    )
    ..registerLazySingleton<ContentRecommendationRepository>(
      () => ContentRecommendationRepositoryImpl(
        dataSource: locator<ContentRecommendationDataSource>(),
      ),
    )
    ..registerLazySingleton<OtpRepository>(
      () => const OtpRepositoryImpl(),
    )
    ..registerLazySingleton<DashboardRepository>(
      () => DashboardRepositoryImpl(
        remoteDataSource: locator<DashboardRemoteDataSource>(),
        calibrationRepository: locator<CalibrationRepository>(),
      ),
    )
    ..registerLazySingleton<DecksRepository>(
      () => DecksRepositoryImpl(
        locator<DecksRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<SyllabotRepository>(
      () => SyllabotRepositoryImpl(
        remoteDataSource: locator<SyllabotRemoteDataSource>(),
        localDataSource: locator<SyllabotLocalDataSource>(),
      ),
    );
}
