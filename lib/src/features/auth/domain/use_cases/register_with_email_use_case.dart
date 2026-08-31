import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class RegisterParams extends Equatable {
  const RegisterParams({
    required this.email,
    required this.password,
    this.displayName,
  });

  final String email;
  final String password;
  final String? displayName;

  @override
  List<Object?> get props => [email, password, displayName];
}

class RegisterWithEmailUseCase with UseCase<UserEntity, RegisterParams> {
  const RegisterWithEmailUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, UserEntity>> call(RegisterParams params) {
    return _repository.registerWithEmail(
      email: params.email,
      password: params.password,
      displayName: params.displayName,
    );
  }
}
