import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';

/// Abstract contract for authentication and profile operations.
abstract class AuthRepository {
  /// Stream observing authentication and onboarding status transitions.
  Stream<AuthSessionStatus> observeAuthState();

  /// Fetches the profile of the current authenticated user.
  Future<Either<Failure, UserProfileEntity>> getUserProfile();

  /// Completes user onboarding, saving their initial course track and goal.
  Future<Either<Failure, UserProfileEntity>> completeOnboarding({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  });

  /// Updates course track and daily review targets from settings.
  Future<Either<Failure, UserProfileEntity>> updateCourseTrack({
    required String track,
    required int dailyTarget,
    double retentionBenchmark = 0.85,
  });

  /// Authenticates using email and password.
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  });

  /// Registers a new user with email and password.
  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  /// Authenticates using OAuth providers (Google, Apple).
  Future<Either<Failure, UserEntity>> loginWithSocial({
    required String provider,
    required String idToken,
    String? rawNonce,
  });

  /// Sends a password reset email.
  Future<Either<Failure, void>> resetPassword({
    required String email,
  });

  /// Sends passwordless magic link to email.
  Future<Either<Failure, void>> sendMagicLink({
    required String email,
  });

  /// Verifies a 6-digit OTP token for account confirmation or login.
  Future<Either<Failure, UserEntity>> verifyOtp({
    required String email,
    required String token,
    String type = 'signup',
  });

  /// Clears session and logs user out.
  Future<Either<Failure, void>> signOut();
}
