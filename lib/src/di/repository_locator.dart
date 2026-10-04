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
        remoteDataSource: locator<CalibrationRemoteDataSource>(),
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
        decksRemoteDataSource: locator<DecksRemoteDataSource>(),
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
        userStorage: locator<UserStorageService>(),
        offlineSyncQueue: locator<ForumOfflineSyncQueue>(),
        connectivity: Connectivity(),
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
      () => PlannerRepositoryImpl(
        database: locator.isRegistered<AppDatabase>()
            ? locator<AppDatabase>()
            : null,
        storageService: locator<LocalStorageService>(),
        userStorageService: locator<UserStorageService>(),
        dio: locator<Dio>(),
        connectivity: Connectivity(),
      ),
    )
    ..registerLazySingleton<QuizRepository>(
      () => QuizRepositoryImpl(
        decksRepository: locator<DecksRepository>(),
        ingestionRepository: locator<IngestionRepository>(),
        studyEngineRouter: locator<StudyEngineRouter>(),
        dio: locator<Dio>(),
        localStorageService: locator<LocalStorageService>(),
        userStorageService: locator<UserStorageService>(),
        userActivityService: locator<UserActivityService>(),
        connectivity: Connectivity(),
      ),
    )
    ..registerLazySingleton<PastQuestionsRepository>(
      () => PastQuestionsRepositoryImpl(
        locator<PastQuestionsRemoteDataSource>(),
        localDataSource: locator<PastQuestionsLocalDataSource>(),
        localStorageService: locator<LocalStorageService>(),
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
    )
    ..registerLazySingleton<CurriculumRepository>(
      () => CurriculumRepositoryImpl(
        locator<CurriculumRemoteDataSource>(),
      ),
    )
    ..registerLazySingleton<QuizDuelRepository>(
      () => QuizDuelRepositoryImpl(
        client: locator<QuizDuelWebSocketClient>(),
      ),
    )
    ..registerLazySingleton<PromoCodeRepository>(
      () => PromoCodeRepositoryImpl(
        remoteDataSource: locator<PromoCodeRemoteDataSource>(),
        userStorageService: locator<UserStorageService>(),
      ),
    )
    ..registerLazySingleton<AppVersionRepository>(
      () => AppVersionRepositoryImpl(
        remoteDataSource: locator<AppVersionRemoteDataSource>(),
      ),
    );
}
