import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_utility/domain/repositories/otp_repository.dart';

/// OTP repository implementation — calls auth API for verify & resend.
/// Swap the stub futures below with actual Retrofit client calls when
/// the backend OTP endpoint is ready.
class OtpRepositoryImpl implements OtpRepository {
  const OtpRepositoryImpl();

  @override
  Future<Either<Failure, bool>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    // TODO(backend): replace with real API call
    return const Right<Failure, bool>(true);
  }

  @override
  Future<Either<Failure, bool>> resendOtp({required String email}) async {
    // TODO(backend): replace with real API call
    return const Right<Failure, bool>(true);
  }
}
