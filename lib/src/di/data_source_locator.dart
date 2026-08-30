part of 'locator.dart';

void _initDataSource() {
  locator.registerLazySingleton<OnboardingLocalDataSource>(
    () => OnboardingLocalDataSourceImpl(
      storageService: locator<LocalStorageService>(),
    ),
  );
}
