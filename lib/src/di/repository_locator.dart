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
    )
    ..registerLazySingleton<IngestionRepository>(
      () => IngestionRepositoryImpl(
        locator<IngestionRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<CommunityRepository>(
      () => CommunityRepositoryImpl(
        locator<CommunityRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<RagRepository>(
      () => RagRepositoryImpl(
        locator<RagRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<LocalOcrRepository>(
      () => LocalOcrRepositoryImpl(
        localDataSource: locator<OcrLocalDataSource>(),
        remoteDataSource: locator<IngestionRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<PlannerRepository>(
      PlannerRepositoryImpl.new,
    );
}
