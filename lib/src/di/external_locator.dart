part of 'locator.dart';

void _initExternal() {
  locator
    ..registerLazySingleton<Dio>(
      () =>
          Dio(
              BaseOptions(
                baseUrl: AppEnv.apiBaseURL,
                connectTimeout: const Duration(seconds: 20),
              ),
            )
            ..interceptors.addAll(
              [
                TokenInterceptor(
                  storageService: locator<UserStorageService>(),
                  sessionExpiredService: locator<SessionExpiredService>(),
                ),
                LoggingInterceptor(logger: locator()),
                DataParserInterceptor(),
              ],
            ),
    )
    ..registerLazySingleton<Logger>(
      Logger.new,
    )
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(
        mOptions: MacOsOptions(
          accessibility: KeychainAccessibility.first_unlock,
        ),
      ),
    )
    ..registerLazySingleton<AppDatabase>(
      AppDatabase.new,
    );
}
