import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/profile/domain/entities/notification_preferences_entity.dart';
import 'package:kortex/src/features/profile/domain/repositories/profile_repository.dart';

class GetNotificationPreferencesUseCase
    implements UseCase<NotificationPreferencesEntity, NoParams> {
  const GetNotificationPreferencesUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, NotificationPreferencesEntity>> call([
    NoParams? params,
  ]) {
    return _repository.getNotificationPreferences();
  }
}

class UpdateNotificationPreferencesUseCase
    implements UseCase<void, NotificationPreferencesEntity> {
  const UpdateNotificationPreferencesUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([
    NotificationPreferencesEntity? params,
  ]) {
    if (params == null) {
      return Future.value(
        const Left(ServerFailure(message: 'Missing notification parameters')),
      );
    }
    return _repository.updateNotificationPreferences(params);
  }
}
