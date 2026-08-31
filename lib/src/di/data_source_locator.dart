part of 'locator.dart';

void _initDataSource() {
  locator
    ..registerLazySingleton<OnboardingLocalDataSource>(
      () => OnboardingLocalDataSourceImpl(
        storageService: locator<LocalStorageService>(),
      ),
    )
    ..registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        apiClient: locator<AuthApiClient>(),
      ),
    )
    ..registerLazySingleton<CalibrationLocalDataSource>(
      () => CalibrationLocalDataSourceImpl(
        storageService: locator<LocalStorageService>(),
      ),
    )
    ..registerLazySingleton<ContentRecommendationDataSource>(
      ContentRecommendationDataSourceImpl.new,
    )
    ..registerLazySingleton<DashboardRemoteDataSource>(
      () => DashboardRemoteDataSourceImpl(
        locator<DashboardApiClient>(),
      ),
    )
    ..registerLazySingleton<DecksRemoteDataSource>(
      () => DecksRemoteDataSourceImpl(
        locator<DecksApiClient>(),
      ),
    );
}
