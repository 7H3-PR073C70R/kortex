import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/extensions/repository_extension.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/profile/data/data_sources/profile_remote_data_source.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';
import 'package:kortex/src/features/profile/domain/repositories/profile_repository.dart';

/// Implementation of [ProfileRepository].
class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<Either<Failure, void>> updateDisplayName(String displayName) {
    return _remoteDataSource.updateDisplayName(displayName).makeRequest();
  }

  @override
  Future<Either<Failure, void>> updateAvatarUrl(String photoUrl) {
    return _remoteDataSource.updateAvatarUrl(photoUrl).makeRequest();
  }

  @override
  Future<Either<Failure, void>> updatePassword(String newPassword) {
    return _remoteDataSource.updatePassword(newPassword).makeRequest();
  }

  @override
  Future<Either<Failure, void>> sendPasswordResetEmail(String email) {
    return _remoteDataSource.sendPasswordResetEmail(email).makeRequest();
  }

  @override
  Future<Either<Failure, MfaEnrollResultEntity>> enrollMfaTotp() {
    return _remoteDataSource
        .enrollMfaTotp()
        .then((res) => res as MfaEnrollResultEntity)
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> verifyMfaTotp({
    required String factorId,
    required String code,
  }) {
    return _remoteDataSource
        .verifyMfaTotp(factorId: factorId, code: code)
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> unenrollMfaTotp(String factorId) {
    return _remoteDataSource.unenrollMfaTotp(factorId).makeRequest();
  }

  @override
  Future<Either<Failure, List<MfaFactorEntity>>> listMfaFactors() {
    return _remoteDataSource
        .listMfaFactors()
        .then((list) => list.cast<MfaFactorEntity>())
        .makeRequest();
  }

  @override
  Future<Either<Failure, void>> signOutOtherSessions() {
    return _remoteDataSource.signOutOtherSessions().makeRequest();
  }

  @override
  Future<Either<Failure, void>> deleteAccount() {
    return _remoteDataSource.deleteAccount().makeRequest();
  }
}
