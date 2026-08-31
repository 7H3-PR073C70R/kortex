import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/auth_status.dart';
import 'package:kortex/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/observe_auth_state_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/update_course_track_use_case.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_draft_cubit.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/pages/auth_page.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_chat_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_form_view.dart';
import 'package:kortex/src/features/auth/presentation/widgets/mode_switch_button.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockLoginWithEmailUseCase extends Mock
    implements LoginWithEmailUseCase {}

class MockRegisterWithEmailUseCase extends Mock
    implements RegisterWithEmailUseCase {}

class MockLoginWithSocialUseCase extends Mock
    implements LoginWithSocialUseCase {}

class MockResetPasswordUseCase extends Mock
    implements ResetPasswordUseCase {}

class MockObserveAuthStateUseCase extends Mock
    implements ObserveAuthStateUseCase {}

class MockUpdateCourseTrackUseCase extends Mock
    implements UpdateCourseTrackUseCase {}

class MockAuthRepository extends Mock implements AuthRepository {}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late MockLoginWithEmailUseCase mockLoginUseCase;
  late MockRegisterWithEmailUseCase mockRegisterUseCase;
  late MockLoginWithSocialUseCase mockSocialUseCase;
  late MockResetPasswordUseCase mockResetUseCase;
  late MockObserveAuthStateUseCase mockObserveUseCase;
  late MockUpdateCourseTrackUseCase mockUpdateTrackUseCase;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockLoginUseCase = MockLoginWithEmailUseCase();
    mockRegisterUseCase = MockRegisterWithEmailUseCase();
    mockSocialUseCase = MockLoginWithSocialUseCase();
    mockResetUseCase = MockResetPasswordUseCase();
    mockObserveUseCase = MockObserveAuthStateUseCase();
    mockUpdateTrackUseCase = MockUpdateCourseTrackUseCase();
    mockAuthRepository = MockAuthRepository();

    when(() => mockObserveUseCase())
        .thenAnswer((_) => Stream.value(AuthSessionStatus.unauthenticated));
    when(() => mockAuthRepository.getUserProfile())
        .thenAnswer((_) async => const Left(ServerFailure(message: 'None')));

    locator
      ..registerLazySingleton<LoginWithEmailUseCase>(() => mockLoginUseCase)
      ..registerLazySingleton<RegisterWithEmailUseCase>(
        () => mockRegisterUseCase,
      )
      ..registerLazySingleton<LoginWithSocialUseCase>(
        () => mockSocialUseCase,
      )
      ..registerLazySingleton<ResetPasswordUseCase>(() => mockResetUseCase)
      ..registerLazySingleton<ObserveAuthStateUseCase>(() => mockObserveUseCase)
      ..registerLazySingleton<UpdateCourseTrackUseCase>(
        () => mockUpdateTrackUseCase,
      )
      ..registerLazySingleton<AuthRepository>(() => mockAuthRepository)
      ..registerFactory<AuthBloc>(
        () => AuthBloc(
          loginWithEmailUseCase: mockLoginUseCase,
          registerWithEmailUseCase: mockRegisterUseCase,
          loginWithSocialUseCase: mockSocialUseCase,
          resetPasswordUseCase: mockResetUseCase,
          observeAuthStateUseCase: mockObserveUseCase,
          updateCourseTrackUseCase: mockUpdateTrackUseCase,
          authRepository: mockAuthRepository,
        ),
      )
      ..registerFactory<AuthModeCubit>(AuthModeCubit.new)
      ..registerFactory<AuthDraftCubit>(AuthDraftCubit.new);
  });

  tearDown(() async {
    await locator.reset();
  });

  group('AuthPage UI & Dual-Mode Test Suite', () {
    testWidgets('renders AuthPage in AI Chat mode initially and shows branding',
        (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AuthPage()));
      await tester.pump();

      expect(find.text('KORTEX'), findsOneWidget);
      expect(find.byType(ModeSwitchButton), findsOneWidget);
      expect(find.byType(SocialAuthBar), findsOneWidget);
      expect(find.byType(AuthChatView), findsOneWidget);
      expect(find.byType(AuthFormView), findsNothing);
    });

    testWidgets('toggling ModeSwitchButton switches to Quick Form view',
        (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AuthPage()));
      await tester.pump();

      expect(find.byType(AuthChatView), findsOneWidget);

      await tester.tap(find.byType(ModeSwitchButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(AuthFormView), findsOneWidget);
      expect(find.byType(AuthChatView), findsNothing);
    });

    testWidgets('SocialAuthBar renders Google and Apple triggers',
        (tester) async {
      await tester.pumpWidget(_wrapWithTheme(const AuthPage()));
      await tester.pump();

      expect(find.text('Google'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
    });
  });
}
