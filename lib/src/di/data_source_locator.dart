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
        authClient: locator<AuthApiClient>(),
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
        userActivityService: locator<UserActivityService>(),
      ),
    )
    ..registerLazySingleton<DecksRemoteDataSource>(
      () => DecksRemoteDataSourceImpl(
        locator<DecksApiClient>(),
        userStorage: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<SyllabotRemoteDataSource>(
      () => SyllabotRemoteDataSourceImpl(
        locator<SyllabotApiClient>(),
        locator<Dio>(),
        userStorage: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<SyllabotLocalDataSource>(
      () => SyllabotLocalDataSourceImpl(
        locator<LocalLlmEngineClient>(),
        storageService: locator<LocalStorageService>(),
      ),
    )
    ..registerLazySingleton<IngestionRemoteDataSource>(
      () => IngestionRemoteDataSourceImpl(
        locator<IngestionApiClient>(),
        locator<Dio>(),
        userStorage: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<CommunityRemoteDataSource>(
      () => CommunityRemoteDataSourceImpl(
        locator<CommunityApiClient>(),
        userStorage: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<RagRemoteDataSource>(
      () => RagRemoteDataSourceImpl(
        locator<VectorSearchClient>(),
      ),
    )
    ..registerLazySingleton<OcrLocalDataSource>(
      () => OcrLocalDataSourceImpl(
        client: locator<LocalMlkitOcrClient>(),
        storageService: locator<LocalStorageService>(),
      ),
    )
    ..registerLazySingleton<LmsImportDataSource>(
      () => LmsImportDataSourceImpl(
        dio: locator<Dio>(),
      ),
    )
    ..registerLazySingleton<PastQuestionsRemoteDataSource>(
      () => PastQuestionsRemoteDataSourceImpl(
        locator<PastQuestionsApiClient>(),
      ),
    )
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl(
        profileApiClient: locator<ProfileApiClient>(),
        userStorage: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<CurriculumRemoteDataSource>(
      () => CurriculumRemoteDataSourceImpl(
        locator<Dio>(),
      ),
    );
}
