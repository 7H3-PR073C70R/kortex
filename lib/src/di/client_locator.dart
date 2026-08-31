part of 'locator.dart';

void _initClients() {
  locator
    ..registerLazySingleton<AuthApiClient>(
      () => AuthApiClient(locator<Dio>()),
    )
    ..registerLazySingleton<DashboardApiClient>(
      () => DashboardApiClient(locator<Dio>()),
    );
}
