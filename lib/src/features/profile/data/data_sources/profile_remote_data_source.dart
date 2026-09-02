import 'package:kortex/src/features/profile/data/models/mfa_enroll_result_model.dart';
import 'package:kortex/src/features/profile/data/models/mfa_factor_model.dart';

/// Contract for Profile & Security remote API data source.
abstract class ProfileRemoteDataSource {
  /// Updates the scholar display name in remote `profiles` table and Auth.
  Future<void> updateDisplayName(String displayName);

  /// Updates the scholar avatar URL in remote `profiles` table and Auth.
  Future<void> updateAvatarUrl(String photoUrl);

  /// Updates the user's password in Auth service.
  Future<void> updatePassword(String newPassword);

  /// Sends a password reset email via Auth service.
  Future<void> sendPasswordResetEmail(String email);

  /// Enrolls in MFA TOTP (returns Factor ID and secret).
  Future<MfaEnrollResultModel> enrollMfaTotp();

  /// Verifies a 6-digit TOTP code for an enrolled factor.
  Future<void> verifyMfaTotp({
    required String factorId,
    required String code,
  });

  /// Unenrolls a TOTP factor.
  Future<void> unenrollMfaTotp(String factorId);

  /// Lists all active MFA factors for the current user.
  Future<List<MfaFactorModel>> listMfaFactors();

  /// Signs out of all other active sessions (remote devices).
  Future<void> signOutOtherSessions();

  /// Permanently deletes the user profile and records from the database.
  Future<void> deleteAccount();
}
