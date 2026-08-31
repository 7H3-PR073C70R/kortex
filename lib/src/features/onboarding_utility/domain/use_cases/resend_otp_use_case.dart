import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_utility/domain/repositories/otp_repository.dart';

/// Requests a new OTP code to be sent to the user's email.
class ResendOtpUseCase {
  const ResendOtpUseCase(this._repository);

  final OtpRepository _repository;

  Future<Either<Failure, bool>> call({required String email}) =>
      _repository.resendOtp(email: email);
}
