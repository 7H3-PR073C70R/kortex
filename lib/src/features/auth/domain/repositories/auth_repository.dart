import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';

/// Abstract contract for authentication data operations.
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> loginWithEmail({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  });

  Future<Either<Failure, UserEntity>> loginWithSocial({
    required String provider,
    required String idToken,
    String? rawNonce,
  });

  Future<Either<Failure, void>> resetPassword({
    required String email,
  });
}
