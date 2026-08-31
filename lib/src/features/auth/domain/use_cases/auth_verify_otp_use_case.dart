import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class AuthVerifyOtpParams extends Equatable {
  const AuthVerifyOtpParams({
    required this.email,
    required this.token,
    this.type = 'signup',
  });

  final String email;
  final String token;
  final String type;

  @override
  List<Object?> get props => [email, token, type];
}

class AuthVerifyOtpUseCase
    with UseCase<UserEntity, AuthVerifyOtpParams> {
  const AuthVerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, UserEntity>> call(AuthVerifyOtpParams params) {
    return _repository.verifyOtp(
      email: params.email,
      token: params.token,
      type: params.type,
    );
  }
}
