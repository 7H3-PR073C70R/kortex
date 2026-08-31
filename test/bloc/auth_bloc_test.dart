import 'dart:async';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
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

class MockLoginWithEmailUseCase extends Mock implements LoginWithEmailUseCase {}

class MockRegisterWithEmailUseCase extends Mock
    implements RegisterWithEmailUseCase {}

class MockLoginWithSocialUseCase extends Mock
    implements LoginWithSocialUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class MockObserveAuthStateUseCase extends Mock
    implements ObserveAuthStateUseCase {}

class MockUpdateCourseTrackUseCase extends Mock
    implements UpdateCourseTrackUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  group('AuthBloc & Route Guard State Stream Test Suite', () {
    late MockLoginWithEmailUseCase mockLoginWithEmailUseCase;
    late MockRegisterWithEmailUseCase mockRegisterWithEmailUseCase;
    late MockLoginWithSocialUseCase mockLoginWithSocialUseCase;
    late MockResetPasswordUseCase mockResetPasswordUseCase;
    late MockObserveAuthStateUseCase mockObserveAuthStateUseCase;
    late MockUpdateCourseTrackUseCase mockUpdateCourseTrackUseCase;
    late MockAuthRepository mockAuthRepository;
    late StreamController<AuthSessionStatus> authStreamController;

    const tUser = UserEntity(
      id: 'user_123',
      email: 'scholar@kortex.app',
    );

    const tProfileComplete = UserProfileEntity(
      id: 'user_123',
      email: 'scholar@kortex.app',
      targetTrack: 'JAMB',
      dailyCardTarget: 25,
      isOnboarded: true,
    );

    const tProfileNeedsOnboarding = UserProfileEntity(
      id: 'user_123',
      email: 'scholar@kortex.app',
    );

    setUp(() {
      mockLoginWithEmailUseCase = MockLoginWithEmailUseCase();
      mockRegisterWithEmailUseCase = MockRegisterWithEmailUseCase();
      mockLoginWithSocialUseCase = MockLoginWithSocialUseCase();
      mockResetPasswordUseCase = MockResetPasswordUseCase();
      mockObserveAuthStateUseCase = MockObserveAuthStateUseCase();
      mockUpdateCourseTrackUseCase = MockUpdateCourseTrackUseCase();
      mockAuthRepository = MockAuthRepository();

      authStreamController = StreamController<AuthSessionStatus>.broadcast();
      when(() => mockObserveAuthStateUseCase())
          .thenAnswer((_) => authStreamController.stream);
    });

    tearDown(() async {
      await authStreamController.close();
    });

    AuthBloc buildBloc() {
      return AuthBloc(
        loginWithEmailUseCase: mockLoginWithEmailUseCase,
        registerWithEmailUseCase: mockRegisterWithEmailUseCase,
        loginWithSocialUseCase: mockLoginWithSocialUseCase,
        resetPasswordUseCase: mockResetPasswordUseCase,
        observeAuthStateUseCase: mockObserveAuthStateUseCase,
        updateCourseTrackUseCase: mockUpdateCourseTrackUseCase,
        authRepository: mockAuthRepository,
      );
    }

    test('initial state has initial status and unauthenticated session',
        () async {
      final bloc = buildBloc();
      expect(bloc.state.status, equals(AuthStatus.initial));
      expect(
        bloc.state.sessionStatus,
        equals(AuthSessionStatus.unauthenticated),
      );
      await bloc.close();
    });

    blocTest<AuthBloc, AuthState>(
      'AuthCheckRequested emits authenticated when profile is onboarded',
      build: () {
        when(() => mockAuthRepository.getUserProfile())
            .thenAnswer((_) async => const Right(tProfileComplete));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.authenticated,
          sessionStatus: AuthSessionStatus.authenticatedComplete,
          userProfile: tProfileComplete,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthCheckRequested emits needsOnboarding when profile is not onboarded',
      build: () {
        when(() => mockAuthRepository.getUserProfile())
            .thenAnswer((_) async => const Right(tProfileNeedsOnboarding));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthCheckRequested()),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.needsOnboarding,
          sessionStatus: AuthSessionStatus.authenticatedNeedsOnboarding,
          userProfile: tProfileNeedsOnboarding,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested emits authenticated on successful email login',
      build: () {
        when(
          () => mockLoginWithEmailUseCase(
            const LoginParams(
              email: 'scholar@kortex.app',
              password: 'Password123!',
            ),
          ),
        ).thenAnswer((_) async => const Right(tUser));

        when(() => mockAuthRepository.getUserProfile())
            .thenAnswer((_) async => const Right(tProfileComplete));

        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'scholar@kortex.app',
          password: 'Password123!',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.authenticated,
          sessionStatus: AuthSessionStatus.authenticatedComplete,
          user: tUser,
        ),
        const AuthState(
          status: AuthStatus.authenticated,
          sessionStatus: AuthSessionStatus.authenticatedComplete,
          user: tUser,
          userProfile: tProfileComplete,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthLoginRequested emits error on invalid credentials',
      build: () {
        when(
          () => mockLoginWithEmailUseCase(
            const LoginParams(
              email: 'scholar@kortex.app',
              password: 'WrongPassword',
            ),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ServerFailure(message: 'Invalid login credentials'),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const AuthLoginRequested(
          email: 'scholar@kortex.app',
          password: 'WrongPassword',
        ),
      ),
      expect: () => [
        const AuthState(status: AuthStatus.loading),
        const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Invalid login credentials',
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AuthSignOutRequested clears user state and resets to unauthenticated',
      build: () {
        when(() => mockAuthRepository.signOut())
            .thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => [
        const AuthState(
          status: AuthStatus.unauthenticated,
        ),
      ],
    );
  });
}
