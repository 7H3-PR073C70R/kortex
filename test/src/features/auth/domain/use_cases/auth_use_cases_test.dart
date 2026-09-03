import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/entities/user_entity.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/observe_auth_state_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/update_course_track_use_case.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepository;
  late LoginWithEmailUseCase loginUseCase;
  late RegisterWithEmailUseCase registerUseCase;
  late LoginWithSocialUseCase socialUseCase;
  late ResetPasswordUseCase resetUseCase;
  late ObserveAuthStateUseCase observeAuthStateUseCase;
  late CompleteOnboardingUseCase completeOnboardingUseCase;
  late UpdateCourseTrackUseCase updateCourseTrackUseCase;

  const tUser = UserEntity(
    id: 'user_123',
    email: 'student@university.edu',
    displayName: 'Ada Lovelace',
    token: 'jwt_token_xyz',
  );

  const tProfile = UserProfileEntity(
    id: 'user_123',
    email: 'student@university.edu',
    displayName: 'Ada Lovelace',
    targetTrack: 'JAMB',
    dailyCardTarget: 25,
    isOnboarded: true,
  );

  setUp(() {
    mockRepository = MockAuthRepository();
    loginUseCase = LoginWithEmailUseCase(mockRepository);
    registerUseCase = RegisterWithEmailUseCase(mockRepository);
    socialUseCase = LoginWithSocialUseCase(mockRepository);
    resetUseCase = ResetPasswordUseCase(mockRepository);
    observeAuthStateUseCase = ObserveAuthStateUseCase(mockRepository);
    completeOnboardingUseCase = CompleteOnboardingUseCase(mockRepository);
    updateCourseTrackUseCase = UpdateCourseTrackUseCase(mockRepository);
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
    });

    test('LoginWithSocialUseCase returns UserEntity on success', () async {
      when(
        () => mockRepository.loginWithSocial(
          provider: 'google',
          idToken: 'token_abc',
          rawNonce: 'nonce_123',
        ),
      ).thenAnswer(
        (_) async => const Right<Failure, UserEntity>(tUser),
      );

      final result = await socialUseCase(
        const SocialAuthParams(
          provider: 'google',
          idToken: 'token_abc',
          rawNonce: 'nonce_123',
        ),
      );

      expect(result, equals(const Right<Failure, UserEntity>(tUser)));
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
    });

    test('ObserveAuthStateUseCase streams auth session status', () async {
      when(() => mockRepository.observeAuthState()).thenAnswer(
        (_) => Stream.value(AuthSessionStatus.authenticatedComplete),
      );

      final stream = observeAuthStateUseCase();

      expect(
        await stream.first,
        equals(AuthSessionStatus.authenticatedComplete),
      );
    });

    test(
      'CompleteOnboardingUseCase updates and returns UserProfileEntity',
      () async {
        when(
          () => mockRepository.completeOnboarding(
            track: 'JAMB',
            dailyTarget: 25,
          ),
        ).thenAnswer(
          (_) async => const Right<Failure, UserProfileEntity>(tProfile),
        );

        final result = await completeOnboardingUseCase(
          track: 'JAMB',
          dailyTarget: 25,
        );

        expect(
          result,
          equals(const Right<Failure, UserProfileEntity>(tProfile)),
        );
      },
    );

    test(
      'UpdateCourseTrackUseCase updates track and returns profile',
      () async {
        when(
          () => mockRepository.updateCourseTrack(
            track: 'JAMB',
            dailyTarget: 25,
          ),
        ).thenAnswer(
          (_) async => const Right<Failure, UserProfileEntity>(tProfile),
        );

        final result = await updateCourseTrackUseCase(
          track: 'JAMB',
          dailyTarget: 25,
        );

        expect(
          result,
          equals(const Right<Failure, UserProfileEntity>(tProfile)),
        );
      },
    );
  });
}
