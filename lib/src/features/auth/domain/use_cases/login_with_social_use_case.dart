import 'package:equatable/equatable.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';

class SocialAuthParams extends Equatable {
  const SocialAuthParams({
    required this.provider,
    required this.idToken,
    this.rawNonce,
  });

  final String provider;
  final String idToken;
  final String? rawNonce;

  @override
  List<Object?> get props => [provider, idToken, rawNonce];
}

class LoginWithSocialUseCase with UseCase<UserEntity, SocialAuthParams> {
  const LoginWithSocialUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Either<Failure, UserEntity>> call(SocialAuthParams params) {
    return _repository.loginWithSocial(
      provider: params.provider,
      idToken: params.idToken,
      rawNonce: params.rawNonce,
    );
  }
}
