import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class ResetPasswordParams extends Equatable {
  const ResetPasswordParams({
    required this.email,
  });

  final String email;

  @override
  List<Object?> get props => [email];
}

class ResetPasswordUseCase with UseCase<void, ResetPasswordParams> {
  const ResetPasswordUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, void>> call(ResetPasswordParams params) {
    return _repository.resetPassword(email: params.email);
  }
}
