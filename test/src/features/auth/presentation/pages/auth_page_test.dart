import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/login_with_social_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/register_with_email_use_case.dart';
import 'package:kortex/src/features/auth/domain/use_cases/reset_password_use_case.dart';
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

  setUp(() {
    mockLoginUseCase = MockLoginWithEmailUseCase();
    mockRegisterUseCase = MockRegisterWithEmailUseCase();
    mockSocialUseCase = MockLoginWithSocialUseCase();
    mockResetUseCase = MockResetPasswordUseCase();

    locator
      ..registerLazySingleton<LoginWithEmailUseCase>(() => mockLoginUseCase)
      ..registerLazySingleton<RegisterWithEmailUseCase>(
        () => mockRegisterUseCase,
      )
      ..registerLazySingleton<LoginWithSocialUseCase>(
        () => mockSocialUseCase,
      )
      ..registerLazySingleton<ResetPasswordUseCase>(() => mockResetUseCase)
      ..registerFactory<AuthBloc>(
        () => AuthBloc(
          loginWithEmailUseCase: mockLoginUseCase,
          registerWithEmailUseCase: mockRegisterUseCase,
          loginWithSocialUseCase: mockSocialUseCase,
          resetPasswordUseCase: mockResetUseCase,
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

    testWidgets(
      'renders desktop two-column split layout on screen width >= 1024',
      (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrapWithTheme(const AuthPage()));
      await tester.pump();

      expect(
        find.text('Your AI-Augmented Academic Workspace'),
        findsOneWidget,
      );
      expect(find.text('Zero-latency multimodal STEM OCR'), findsOneWidget);
    });
  });
}
