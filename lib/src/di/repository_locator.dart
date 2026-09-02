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
        decksRemoteDataSource: locator<DecksRemoteDataSource>(),
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
    ..registerLazySingleton<EphemeralRoomRepository>(
      () => EphemeralRoomRepositoryImpl(
        presenceClient: locator<EphemeralPresenceClient>(),
        communityClient: locator<CommunityApiClient>(),
      ),
    )
    ..registerLazySingleton<PlannerRepository>(
      PlannerRepositoryImpl.new,
    )
    ..registerLazySingleton<QuizRepository>(
      QuizRepositoryImpl.new,
    )
    ..registerLazySingleton<PastQuestionsRepository>(
      () => PastQuestionsRepositoryImpl(
        locator<PastQuestionsRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<LmsRepository>(
      () => LmsRepositoryImpl(
        dataSource: locator<LmsImportDataSource>(),
      ),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(
        remoteDataSource: locator<ProfileRemoteDataSource>(),
      ),
    );
}
