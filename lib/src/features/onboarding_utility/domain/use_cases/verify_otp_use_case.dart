import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_utility/domain/repositories/otp_repository.dart';

/// Verifies a submitted OTP code against the backend.
class VerifyOtpUseCase {
  const VerifyOtpUseCase(this._repository);

  final OtpRepository _repository;

  Future<Either<Failure, bool>> call({
    required String email,
    required String otp,
  }) => _repository.verifyOtp(email: email, otp: otp);
}
