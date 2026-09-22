import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/error/failure.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/di/locator.dart';
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
import 'package:kortex/src/features/auth/presentation/bloc/auth_mode_cubit.dart';
import 'package:kortex/src/features/auth/presentation/widgets/auth_flow_panel.dart';
import 'package:kortex/src/features/auth/presentation/widgets/social_auth_bar.dart';
import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:kortex/src/features/onboarding/presentation/pages/splash_page.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/animated_page_indicator.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_illustrations.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

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

/// Registers the live auth bloc stack the wide split layout resolves from
/// the locator (mirrors the production lazy-singleton graph and the
/// AuthPage test harness).
void _registerAuthFlowMocks() {
  final mockLoginUseCase = MockLoginWithEmailUseCase();
  final mockRegisterUseCase = MockRegisterWithEmailUseCase();
  final mockVerifyOtpUseCase = MockAuthVerifyOtpUseCase();
  final mockSocialUseCase = MockLoginWithSocialUseCase();
  final mockResetUseCase = MockResetPasswordUseCase();
  final mockObserveUseCase = MockObserveAuthStateUseCase();
  final mockUpdateTrackUseCase = MockUpdateCourseTrackUseCase();
  final mockAuthRepository = MockAuthRepository();

  when(
    mockObserveUseCase.call,
  ).thenAnswer((_) => Stream.value(AuthSessionStatus.unauthenticated));
  when(
    mockAuthRepository.getUserProfile,
  ).thenAnswer((_) async => const Left(ServerFailure(message: 'None')));

  locator
    ..registerLazySingleton<LoginWithEmailUseCase>(() => mockLoginUseCase)
    ..registerLazySingleton<RegisterWithEmailUseCase>(
      () => mockRegisterUseCase,
    )
    ..registerLazySingleton<AuthVerifyOtpUseCase>(() => mockVerifyOtpUseCase)
    ..registerLazySingleton<LoginWithSocialUseCase>(() => mockSocialUseCase)
    ..registerLazySingleton<ResetPasswordUseCase>(() => mockResetUseCase)
    ..registerLazySingleton<ObserveAuthStateUseCase>(() => mockObserveUseCase)
    ..registerLazySingleton<UpdateCourseTrackUseCase>(
      () => mockUpdateTrackUseCase,
    )
    ..registerLazySingleton<AuthRepository>(() => mockAuthRepository)
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        loginWithEmailUseCase: mockLoginUseCase,
        registerWithEmailUseCase: mockRegisterUseCase,
        loginWithSocialUseCase: mockSocialUseCase,
        resetPasswordUseCase: mockResetUseCase,
        observeAuthStateUseCase: mockObserveUseCase,
        updateCourseTrackUseCase: mockUpdateTrackUseCase,
        verifyOtpUseCase: mockVerifyOtpUseCase,
        authRepository: mockAuthRepository,
      ),
    )
    ..registerLazySingleton<AuthModeCubit>(AuthModeCubit.new);
}

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

  late MockLocalStorageService mockStorage;

  setUp(() {
    mockStorage = MockLocalStorageService();
    locator
      ..registerSingleton<LocalStorageService>(mockStorage)
      ..registerLazySingleton<OnboardingLocalDataSource>(
        () => OnboardingLocalDataSourceImpl(storageService: mockStorage),
      );
  });

  tearDown(() async {
    await locator.reset();
  });

  group('Onboarding & Splash Feature Test Suite', () {
    testWidgets(
      'AnimatedPageIndicator renders correct items and marks active',
      (tester) async {
        var selectedIndex = 0;
        await tester.pumpWidget(
          _wrapWithTheme(
            AnimatedPageIndicator(
              count: 4,
              currentIndex: 1,
              onTap: (index) => selectedIndex = index,
            ),
          ),
        );

        expect(find.byType(AnimatedPageIndicator), findsOneWidget);
        await tester.tap(find.byType(GestureDetector).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(selectedIndex, equals(0));
      },
    );

    testWidgets('OnboardingIllustrations render without errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          Builder(
            builder: (context) => SingleChildScrollView(
              child: Column(
                children: [
                  OnboardingIllustrations.documentIngestion(context: context),
                  OnboardingIllustrations.stemOcr(context: context),
                  OnboardingIllustrations.spacedRepetition(context: context),
                  OnboardingIllustrations.socraticAi(context: context),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(OnboardingIllustrations), findsNothing);
    });

    testWidgets(
      'OnboardingPage renders and slides advance with forward button',
      (tester) async {
        when(
          () => mockStorage.savePreference(
            key: PrefKeys.hasCompletedOnboarding,
            data: 'true',
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(_wrapWithTheme(const OnboardingPage()));
        await tester.pump();

        expect(find.text('KORTEXIFY'), findsOneWidget);
        expect(find.text('Drop. Parse. Master.'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Flawless Math & Science OCR'), findsOneWidget);
      },
    );

    testWidgets(
      'OnboardingPage renders wide split layout with live auth workspace '
      'on desktop/web viewports',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        _registerAuthFlowMocks();
        when(
          () => mockStorage.savePreference(
            key: any(named: 'key'),
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(_wrapWithTheme(const OnboardingPage()));
        await tester.pump();

        // Carousel pane still leads with the first slide.
        expect(find.text('Drop. Parse. Master.'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);

        // The real Auth/Signup flow sits beside the carousel instead of
        // the mobile flow being stretched across the viewport. (The chat
        // canvas surfaces its own social dock inline, hence two bars.)
        expect(find.byType(AuthWorkspacePanel), findsOneWidget);
        expect(find.byType(SocialAuthBar), findsNWidgets(2));

        // Paging forward works and reveals the Previous control. (Pumps
        // step frame-by-frame: one large time jump can leave PageView's
        // snap activity mid-transition in tests.)
        await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 180));

        expect(find.text('Flawless Math & Science OCR'), findsOneWidget);
        expect(find.text('Previous'), findsOneWidget);

        // Paging back returns to slide one and hides the Previous control.
        await tester.tap(find.text('Previous'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 160));
        await tester.pump(const Duration(milliseconds: 180));

        expect(find.text('Drop. Parse. Master.'), findsOneWidget);
        expect(find.text('Previous'), findsNothing);
      },
    );

    testWidgets('SplashPage renders brand identity and Syllabot engine pill', (
      tester,
    ) async {
      when(
        () => mockStorage.getPreference(
          key: PrefKeys.hasCompletedOnboarding,
        ),
      ).thenReturn('false');

      await tester.pumpWidget(_wrapWithTheme(const SplashPage()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('KORTEXIFY'), findsOneWidget);
      expect(find.text('ENGINE: SYLLABOT AI'), findsOneWidget);
    });
  });
}
