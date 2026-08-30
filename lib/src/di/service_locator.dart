part of 'locator.dart';

void _initServices() {
  locator
    ..registerLazySingleton<UserStorageService>(
      () => UserStorageServiceImpl(locator()),
    )
    ..registerLazySingleton<LocalStorageService>(
      LocalStorageServiceImpl.new,
    )
    ..registerLazySingleton<ThemeCubit>(
      () => ThemeCubit(storageService: locator()),
    );
}
