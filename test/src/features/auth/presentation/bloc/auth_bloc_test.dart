import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginWithEmailUseCase extends Mock
    implements LoginWithEmailUseCase {}

class MockRegisterWithEmailUseCase extends Mock
    implements RegisterWithEmailUseCase {}

class MockLoginWithSocialUseCase extends Mock
    implements LoginWithSocialUseCase {}

class MockResetPasswordUseCase extends Mock
    implements ResetPasswordUseCase {}

void main() {
  late MockLoginWithEmailUseCase mockLoginUseCase;
  late MockRegisterWithEmailUseCase mockRegisterUseCase;
  late MockLoginWithSocialUseCase mockSocialUseCase;
  late MockResetPasswordUseCase mockResetUseCase;

  const tUser = UserEntity(
    id: 'user_123',
    email: 'student@university.edu',
    displayName: 'Ada Lovelace',
  );

  setUpAll(() {
    registerFallbackValue(
      const LoginParams(email: 'test', password: 'test'),
    );
    registerFallbackValue(
      const RegisterParams(email: 'test', password: 'test'),
    );
    registerFallbackValue(
      const SocialAuthParams(provider: 'google', idToken: 'token'),
    );
    registerFallbackValue(
      const ResetPasswordParams(email: 'test'),
    );
  });

  setUp(() {
    mockLoginUseCase = MockLoginWithEmailUseCase();
    mockRegisterUseCase = MockRegisterWithEmailUseCase();
    mockSocialUseCase = MockLoginWithSocialUseCase();
    mockResetUseCase = MockResetPasswordUseCase();
  });

  AuthBloc buildBloc() {
    return AuthBloc(
      loginWithEmailUseCase: mockLoginUseCase,
      registerWithEmailUseCase: mockRegisterUseCase,
      loginWithSocialUseCase: mockSocialUseCase,
      resetPasswordUseCase: mockResetUseCase,
    );
  }

  group('AuthBloc Test Suite', () {
    test('initial state has AuthStatus.initial', () {
      expect(buildBloc().state, equals(const AuthState()));
    });

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when login succeeds',
      build: () {
        when(() => mockLoginUseCase(any()))
            .thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'student@university.edu',
          password: 'password123',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.authenticated, user: tUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, error] when login fails',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => const Left(
            ServerFailure(message: 'Invalid credentials'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'student@university.edu',
          password: 'wrong_password',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Invalid credentials',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, needsEmailVerification] when register succeeds',
      build: () {
        when(() => mockRegisterUseCase(any()))
            .thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthRegisterRequested(
          email: 'student@university.edu',
          password: 'password123',
          displayName: 'Ada Lovelace',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.needsEmailVerification,
          user: tUser,
          needsEmailVerification: true,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, authenticated] when social login succeeds',
      build: () {
        when(() => mockSocialUseCase(any()))
            .thenAnswer((_) async => const Right(tUser));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthSocialLoginRequested(
          provider: 'google',
          idToken: 'google_token',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.authenticated, user: tUser),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [loading, resetSent] when reset password succeeds',
      build: () {
        when(() => mockResetUseCase(any()))
            .thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthResetPasswordRequested(
          email: 'student@university.edu',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(status: AuthStatus.resetSent),
      ],
    );
  });
}
