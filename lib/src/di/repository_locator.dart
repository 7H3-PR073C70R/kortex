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
    );
}
