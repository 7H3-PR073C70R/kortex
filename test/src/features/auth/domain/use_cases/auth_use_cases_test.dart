import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late LoginWithEmailUseCase loginUseCase;
  late RegisterWithEmailUseCase registerUseCase;
  late LoginWithSocialUseCase socialUseCase;
  late ResetPasswordUseCase resetUseCase;

  const tUser = UserEntity(
    id: 'user_123',
    email: 'student@university.edu',
    displayName: 'Ada Lovelace',
    token: 'jwt_token_xyz',
  );

  setUp(() {
    mockRepository = MockAuthRepository();
    loginUseCase = LoginWithEmailUseCase(mockRepository);
    registerUseCase = RegisterWithEmailUseCase(mockRepository);
    socialUseCase = LoginWithSocialUseCase(mockRepository);
    resetUseCase = ResetPasswordUseCase(mockRepository);
  });

  group('Auth UseCases Test Suite', () {
    test('LoginWithEmailUseCase returns UserEntity on success', () async {
      when(
        () => mockRepository.loginWithEmail(
          email: 'student@university.edu',
          password: 'password123',
        ),
      ).thenAnswer(
        (_) async => const Right<Failure, UserEntity>(tUser),
      );

      final result = await loginUseCase(
        const LoginParams(
          email: 'student@university.edu',
          password: 'password123',
        ),
      );

      expect(result, equals(const Right<Failure, UserEntity>(tUser)));
      verify(
        () => mockRepository.loginWithEmail(
          email: 'student@university.edu',
          password: 'password123',
        ),
      ).called(1);
    });

    test('RegisterWithEmailUseCase returns UserEntity on success', () async {
      when(
        () => mockRepository.registerWithEmail(
          email: 'student@university.edu',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ).thenAnswer(
        (_) async => const Right<Failure, UserEntity>(tUser),
      );

      final result = await registerUseCase(
        const RegisterParams(
          email: 'student@university.edu',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      );

      expect(result, equals(const Right<Failure, UserEntity>(tUser)));
      verify(
        () => mockRepository.registerWithEmail(
          email: 'student@university.edu',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ).called(1);
    });

    test('LoginWithSocialUseCase returns UserEntity on success', () async {
      when(
        () => mockRepository.loginWithSocial(
          provider: 'google',
          idToken: 'google_id_token',
        ),
      ).thenAnswer(
        (_) async => const Right<Failure, UserEntity>(tUser),
      );

      final result = await socialUseCase(
        const SocialAuthParams(
          provider: 'google',
          idToken: 'google_id_token',
        ),
      );

      expect(result, equals(const Right<Failure, UserEntity>(tUser)));
      verify(
        () => mockRepository.loginWithSocial(
          provider: 'google',
          idToken: 'google_id_token',
        ),
      ).called(1);
    });

    test('ResetPasswordUseCase returns Right(null) on success', () async {
      when(
        () => mockRepository.resetPassword(
          email: 'student@university.edu',
        ),
      ).thenAnswer(
        (_) async => const Right<Failure, void>(null),
      );

      final result = await resetUseCase(
        const ResetPasswordParams(
          email: 'student@university.edu',
        ),
      );

      expect(result, equals(const Right<Failure, void>(null)));
      verify(
        () => mockRepository.resetPassword(
          email: 'student@university.edu',
        ),
      ).called(1);
    });

    test('LoginWithEmailUseCase returns Left(Failure) on error', () async {
      when(
        () => mockRepository.loginWithEmail(
          email: 'student@university.edu',
          password: 'wrong_password',
        ),
      ).thenAnswer(
        (_) async => const Left<Failure, UserEntity>(
          ServerFailure(message: 'Invalid credentials'),
        ),
      );

      final result = await loginUseCase(
        const LoginParams(
          email: 'student@university.edu',
          password: 'wrong_password',
        ),
      );

      expect(
        result,
        equals(
          const Left<Failure, UserEntity>(
            ServerFailure(message: 'Invalid credentials'),
          ),
        ),
      );
    });
  });
}
