import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/profile/domain/repositories/profile_repository.dart';

class UpdatePasswordUseCase implements UseCase<void, String> {
  const UpdatePasswordUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([String? params]) {
    return _repository.updatePassword(params ?? '');
  }
}
