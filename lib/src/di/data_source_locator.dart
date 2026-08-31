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
        authClient: locator<SupabaseAuthClient>(),
        userStorage: locator<UserStorageService>(),
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
    )
    ..registerLazySingleton<SyllabotRemoteDataSource>(
      () => SyllabotRemoteDataSourceImpl(
        locator<SupabaseSyllabotClient>(),
        locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<SyllabotLocalDataSource>(
      () => SyllabotLocalDataSourceImpl(
        locator<LocalLlmEngineClient>(),
      ),
    )
    ..registerLazySingleton<IngestionRemoteDataSource>(
      () => IngestionRemoteDataSourceImpl(
        locator<SupabaseIngestionClient>(),
        locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<CommunityRemoteDataSource>(
      () => CommunityRemoteDataSourceImpl(
        locator<SupabaseCommunityClient>(),
        locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<RagRemoteDataSource>(
      () => RagRemoteDataSourceImpl(
        locator<VectorSearchClient>(),
        locator<UserStorageService>(),
      ),
    );
}
