part of 'locator.dart';

void _initExternal() {
  locator
    ..registerLazySingleton<Dio>(
      () => Dio(
        BaseOptions(
          baseUrl: AppEnv.apiBaseURL,
          contentType: 'application/json',
          connectTimeout: const Duration(seconds: 20),
        ),
      )..interceptors.addAll(
          [
            LoggingInterceptor(logger: locator()),
            TokenInterceptor(storageService: locator()),
            DataParserInterceptor(),
          ],
        ),
    )
    ..registerLazySingleton<Logger>(
      Logger.new,
    );
}
