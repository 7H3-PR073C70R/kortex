import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';

/// Abstract contract for OTP verification operations.
abstract class OtpRepository {
  /// Verifies a one-time-password for the given [email].
  Future<Either<Failure, bool>> verifyOtp({
    required String email,
    required String otp,
  });

  /// Resends an OTP to the given [email].
  Future<Either<Failure, bool>> resendOtp({required String email});
}
