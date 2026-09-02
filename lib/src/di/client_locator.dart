part of 'locator.dart';

void _initClients() {
  locator
    ..registerLazySingleton<AuthApiClient>(
      () => AuthApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<DashboardApiClient>(
      () => DashboardApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<DecksApiClient>(
      () => DecksApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<SyllabotApiClient>(
      () => SyllabotApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<IngestionApiClient>(
      () => IngestionApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<CommunityApiClient>(
      () => CommunityApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<VectorSearchClient>(
      () => VectorSearchClient(locator<Dio>()),
    )
    ..registerLazySingleton<LocalLlmEngineClient>(
      LocalLlmEngineClient.new,
    )
    ..registerLazySingleton<LocalMlkitOcrClient>(
      LocalMlkitOcrClient.new,
    )
    ..registerLazySingleton<SpeechToTextClient>(
      SpeechToTextClient.new,
    )
    ..registerLazySingleton<TextToSpeechClient>(
      TextToSpeechClient.new,
    )
    ..registerLazySingleton<EphemeralPresenceClient>(
      EphemeralPresenceClientImpl.new,
    )
    ..registerLazySingleton<PastQuestionsApiClient>(
      () => PastQuestionsApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<ProfileApiClient>(
      () => ProfileApiClient(locator<Dio>()),
    );
}
