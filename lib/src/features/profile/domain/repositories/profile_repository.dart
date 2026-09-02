import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_enroll_result_entity.dart';
import 'package:kortex/src/features/profile/domain/entities/mfa_factor_entity.dart';

/// Domain Repository Interface for Profile & Security.
abstract class ProfileRepository {
  Future<Either<Failure, void>> updateDisplayName(String displayName);
  Future<Either<Failure, void>> updateAvatarUrl(String photoUrl);
  Future<Either<Failure, void>> updatePassword(String newPassword);
  Future<Either<Failure, void>> sendPasswordResetEmail(String email);
  Future<Either<Failure, MfaEnrollResultEntity>> enrollMfaTotp();
  Future<Either<Failure, void>> verifyMfaTotp({
    required String factorId,
    required String code,
  });
  Future<Either<Failure, void>> unenrollMfaTotp(String factorId);
  Future<Either<Failure, List<MfaFactorEntity>>> listMfaFactors();
  Future<Either<Failure, void>> signOutOtherSessions();
  Future<Either<Failure, void>> deleteAccount();
}
