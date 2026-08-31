import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/auth_verify_otp_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/observe_auth_state_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/update_course_track_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginWithEmailUseCase extends Mock
    implements LoginWithEmailUseCase {}

class MockRegisterWithEmailUseCase extends Mock
    implements RegisterWithEmailUseCase {}

class MockAuthVerifyOtpUseCase extends Mock
    implements AuthVerifyOtpUseCase {}

class MockLoginWithSocialUseCase extends Mock
    implements LoginWithSocialUseCase {}

class MockResetPasswordUseCase extends Mock
    implements ResetPasswordUseCase {}

class MockObserveAuthStateUseCase extends Mock
    implements ObserveAuthStateUseCase {}

class MockUpdateCourseTrackUseCase extends Mock
    implements UpdateCourseTrackUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockLoginWithEmailUseCase mockLoginUseCase;
  late MockRegisterWithEmailUseCase mockRegisterUseCase;
  late MockAuthVerifyOtpUseCase mockVerifyOtpUseCase;
  late MockLoginWithSocialUseCase mockSocialUseCase;
  late MockResetPasswordUseCase mockResetUseCase;
  late MockObserveAuthStateUseCase mockObserveUseCase;
  late MockUpdateCourseTrackUseCase mockUpdateTrackUseCase;
  late MockAuthRepository mockAuthRepository;

  const tUser = UserEntity(
    id: 'user_123',
    email: 'student@university.edu',
    displayName: 'Ada Lovelace',
  );

  const tProfile = UserProfileEntity(
    id: 'user_123',
    email: 'student@university.edu',
    displayName: 'Ada Lovelace',
    targetTrack: 'JAMB',
    dailyCardTarget: 25,
    isOnboarded: true,
  );

  setUpAll(() {
    registerFallbackValue(
      const LoginParams(email: 'test', password: 'test'),
    );
    registerFallbackValue(
      const RegisterParams(email: 'test', password: 'test'),
    );
    registerFallbackValue(
      const AuthVerifyOtpParams(email: 'test', token: '123456'),
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
    mockVerifyOtpUseCase = MockAuthVerifyOtpUseCase();
    mockSocialUseCase = MockLoginWithSocialUseCase();
    mockResetUseCase = MockResetPasswordUseCase();
    mockObserveUseCase = MockObserveAuthStateUseCase();
    mockUpdateTrackUseCase = MockUpdateCourseTrackUseCase();
    mockAuthRepository = MockAuthRepository();

    when(() => mockObserveUseCase())
        .thenAnswer((_) => const Stream.empty());
    when(() => mockAuthRepository.getUserProfile())
        .thenAnswer((_) async => const Right(tProfile));
  });

  AuthBloc buildBloc() {
    return AuthBloc(
      loginWithEmailUseCase: mockLoginUseCase,
      registerWithEmailUseCase: mockRegisterUseCase,
      loginWithSocialUseCase: mockSocialUseCase,
      resetPasswordUseCase: mockResetUseCase,
      observeAuthStateUseCase: mockObserveUseCase,
      updateCourseTrackUseCase: mockUpdateTrackUseCase,
      verifyOtpUseCase: mockVerifyOtpUseCase,
      authRepository: mockAuthRepository,
    );
  }

  group('AuthBloc Test Suite', () {
    test('initial state has unauthenticated sessionStatus', () {
      final bloc = buildBloc();
      expect(bloc.state.status, equals(AuthStatus.initial));
      expect(
        bloc.state.sessionStatus,
        equals(AuthSessionStatus.unauthenticated),
      );
      expect(bloc.state.user, isNull);
    });

    blocTest<AuthBloc, AuthState>(
      'emits loading and authenticated on successful login',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => const Right<Failure, UserEntity>(tUser),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'student@university.edu',
          password: 'password123',
        ),
      ),
      expect: () => [
        const AuthState(
          status: AuthStatus.loading,
        ),
        const AuthState(
          status: AuthStatus.authenticated,
          sessionStatus: AuthSessionStatus.authenticatedComplete,
          user: tUser,
        ),
        const AuthState(
          status: AuthStatus.authenticated,
          sessionStatus: AuthSessionStatus.authenticatedComplete,
          user: tUser,
          userProfile: tProfile,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits error when login fails with ServerFailure',
      build: () {
        when(() => mockLoginUseCase(any())).thenAnswer(
          (_) async => const Left<Failure, UserEntity>(
            ServerFailure(message: 'Invalid credentials'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'student@university.edu',
          password: 'wrongpassword',
        ),
      ),
      expect: () => [
        const AuthState(
          status: AuthStatus.loading,
        ),
        const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Invalid credentials',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits needsEmailVerification on registration',
      build: () {
        when(() => mockRegisterUseCase(any())).thenAnswer(
          (_) async => const Right<Failure, UserEntity>(tUser),
        );
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
        const AuthState(
          status: AuthStatus.loading,
        ),
        const AuthState(
          status: AuthStatus.needsEmailVerification,
          needsEmailVerification: true,
          user: tUser,
        ),
      ],
    );
  });
}
