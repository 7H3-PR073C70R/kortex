import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/auth_verify_otp_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/observe_auth_state_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/update_course_track_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_chat_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_action_controls.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_chat_bubbles.dart';
import 'package:kortex/src/features/auth/presentation/widgets/chat/auth_post_login_coordinator.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/pump_app.dart';

class MockLoginWithEmailUseCase extends Mock implements LoginWithEmailUseCase {}

class MockRegisterWithEmailUseCase extends Mock
    implements RegisterWithEmailUseCase {}

class MockAuthVerifyOtpUseCase extends Mock implements AuthVerifyOtpUseCase {}

class MockLoginWithSocialUseCase extends Mock
    implements LoginWithSocialUseCase {}

class MockResetPasswordUseCase extends Mock implements ResetPasswordUseCase {}

class MockObserveAuthStateUseCase extends Mock
    implements ObserveAuthStateUseCase {}

class MockUpdateCourseTrackUseCase extends Mock
    implements UpdateCourseTrackUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthPostLoginCoordinator extends Mock
    implements AuthPostLoginCoordinator {}

void main() {
  group('AuthChatView Standalone Widget Tests', () {
    late MockLoginWithEmailUseCase mockLogin;
    late MockRegisterWithEmailUseCase mockRegister;
    late MockAuthVerifyOtpUseCase mockOtp;
    late MockLoginWithSocialUseCase mockSocial;
    late MockResetPasswordUseCase mockReset;
    late MockObserveAuthStateUseCase mockObserve;
    late MockUpdateCourseTrackUseCase mockUpdateTrack;
    late MockAuthRepository mockRepo;
    late MockAuthPostLoginCoordinator mockPostLoginCoordinator;

    late AuthBloc authBloc;
    late AuthDraftCubit draftCubit;
    late AuthModeCubit modeCubit;

    setUp(() {
      mockLogin = MockLoginWithEmailUseCase();
      mockRegister = MockRegisterWithEmailUseCase();
      mockOtp = MockAuthVerifyOtpUseCase();
      mockSocial = MockLoginWithSocialUseCase();
      mockReset = MockResetPasswordUseCase();
      mockObserve = MockObserveAuthStateUseCase();
      mockUpdateTrack = MockUpdateCourseTrackUseCase();
      mockRepo = MockAuthRepository();
      mockPostLoginCoordinator = MockAuthPostLoginCoordinator();

      when(() => mockObserve()).thenAnswer(
        (_) => Stream.value(AuthSessionStatus.unauthenticated),
      );
      when(() => mockRepo.getUserProfile()).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'None')),
      );

      authBloc = AuthBloc(
        loginWithEmailUseCase: mockLogin,
        registerWithEmailUseCase: mockRegister,
        verifyOtpUseCase: mockOtp,
        loginWithSocialUseCase: mockSocial,
        resetPasswordUseCase: mockReset,
        observeAuthStateUseCase: mockObserve,
        updateCourseTrackUseCase: mockUpdateTrack,
        authRepository: mockRepo,
      );
      draftCubit = AuthDraftCubit();
      modeCubit = AuthModeCubit();
    });

    tearDown(() async {
      await authBloc.close();
      await draftCubit.close();
      await modeCubit.close();
    });

    Widget buildSubject() {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider.value(value: draftCubit),
          BlocProvider.value(value: modeCubit),
        ],
        child: Scaffold(
          body: AuthChatView(
            onGooglePressed: () {},
            onForgotPassword: () {},
            postLoginCoordinator: mockPostLoginCoordinator,
          ),
        ),
      );
    }

    testWidgets('renders initial greeting bubble and action controls', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());
      await tester.pump();

      // Bot welcome bubble should appear
      expect(find.byType(AuthBotMessageBubble), findsOneWidget);
      expect(find.textContaining('Syllabot'), findsOneWidget);

      // Action controls should be displayed
      expect(find.byType(AuthChatActionControls), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('tapping Create Account transitions step to signUpName', (
      tester,
    ) async {
      await tester.pumpApp(buildSubject());
      await tester.pump();

      await tester.tap(find.text('Create Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // User bubble should show choice
      expect(find.byType(AuthUserMessageBubble), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}
