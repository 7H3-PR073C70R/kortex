import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_utility/domain/repositories/otp_repository.dart';

/// Legacy OTP repository implementation.
///
/// Authentication verification and password recovery are handled natively
/// via Auth password reset links (`AuthResetPasswordRequested`)
/// and direct registration (`AuthRegisterRequested`).
class OtpRepositoryImpl implements OtpRepository {
  const OtpRepositoryImpl();

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    // Auth client handles verification through magic links & tokens.
    return const Right<Failure, bool>(true);
  }

  @override
  Future<Either<Failure, bool>> resendOtp({required String email}) async {
    // Auth client sends password reset and magic links directly.
    return const Right<Failure, bool>(true);
  }
}
