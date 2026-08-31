part of 'locator.dart';

void _initClients() {
  locator
    ..registerLazySingleton<AuthApiClient>(
      () => AuthApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<SupabaseAuthClient>(
      () => SupabaseAuthClient(locator<Dio>()),
    )
    ..registerLazySingleton<DashboardApiClient>(
      () => DashboardApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<DecksApiClient>(
      () => DecksApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<SupabaseSyllabotClient>(
      () => SupabaseSyllabotClient(locator<Dio>()),
    )
    ..registerLazySingleton<SupabaseIngestionClient>(
      () => SupabaseIngestionClient(locator<Dio>()),
    )
    ..registerLazySingleton<SupabaseCommunityClient>(
      () => SupabaseCommunityClient(locator<Dio>()),
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
    );
}
