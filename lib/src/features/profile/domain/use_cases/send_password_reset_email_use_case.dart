import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/profile/domain/repositories/profile_repository.dart';

class SendPasswordResetEmailUseCase implements UseCase<void, String> {
  const SendPasswordResetEmailUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([String? params]) {
    return _repository.sendPasswordResetEmail(params ?? '');
  }
}
