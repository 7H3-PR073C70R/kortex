import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';
import 'package:kortex/src/features/profile/domain/repositories/profile_repository.dart';

class EnrollMfaTotpUseCase implements UseCase<MfaEnrollResultEntity, NoParams> {
  const EnrollMfaTotpUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, MfaEnrollResultEntity>> call([NoParams? params]) {
    return _repository.enrollMfaTotp();
  }
}

class VerifyMfaTotpParams {
  const VerifyMfaTotpParams({
    required this.factorId,
    required this.code,
  });

  final String factorId;
  final String code;
}

class VerifyMfaTotpUseCase implements UseCase<void, VerifyMfaTotpParams> {
  const VerifyMfaTotpUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([VerifyMfaTotpParams? params]) {
    if (params == null) {
      return Future.value(
        const Left(ServerFailure(message: 'Missing verification parameters')),
      );
    }
    return _repository.verifyMfaTotp(
      factorId: params.factorId,
      code: params.code,
    );
  }
}

class UnenrollMfaTotpUseCase implements UseCase<void, String> {
  const UnenrollMfaTotpUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([String? params]) {
    return _repository.unenrollMfaTotp(params ?? '');
  }
}

class ListMfaFactorsUseCase
    implements UseCase<List<MfaFactorEntity>, NoParams> {
  const ListMfaFactorsUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, List<MfaFactorEntity>>> call([NoParams? params]) {
    return _repository.listMfaFactors();
  }
}

class SignOutOtherSessionsUseCase implements UseCase<void, NoParams> {
  const SignOutOtherSessionsUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([NoParams? params]) {
    return _repository.signOutOtherSessions();
  }
}

class DeleteAccountUseCase implements UseCase<void, NoParams> {
  const DeleteAccountUseCase(this._repository);
  final ProfileRepository _repository;

  @override
  Future<Either<Failure, void>> call([NoParams? params]) {
    return _repository.deleteAccount();
  }
}
