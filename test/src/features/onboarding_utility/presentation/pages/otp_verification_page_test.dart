import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/repositories/calibration_repository.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/bloc/otp_cubit.dart';
import 'package:kortex/src/features/onboarding_utility/presentation/pages/otp_verification_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockOtpCubit extends MockCubit<OtpState> implements OtpCubit {}

class MockCalibrationRepository extends Mock implements CalibrationRepository {}

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

void main() {
  late MockOtpCubit mockOtpCubit;
  late MockCalibrationRepository mockCalibrationRepository;

  setUp(() async {
    final locator = GetIt.instance;
    mockOtpCubit = MockOtpCubit();
    mockCalibrationRepository = MockCalibrationRepository();

    if (locator.isRegistered<OtpCubit>()) {
      await locator.unregister<OtpCubit>();
    }
    locator.registerFactory<OtpCubit>(() => mockOtpCubit);

    if (locator.isRegistered<CalibrationRepository>()) {
      await locator.unregister<CalibrationRepository>();
    }
    locator.registerFactory<CalibrationRepository>(
      () => mockCalibrationRepository,
    );

    when(() => mockOtpCubit.state).thenReturn(
      const OtpState(),
    );
    when(() => mockOtpCubit.startCountdown()).thenReturn(null);
  });

  group('OtpVerificationPage Test Suite', () {
    testWidgets('renders title, email, 6 pin input boxes, and verify button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          const OtpVerificationPage(email: 'scholar@kortex.ai'),
        ),
      );
      await tester.pump();

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(
        find.textContaining('scholar@kortex.ai'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.text('Verify Email'), findsOneWidget);
    });

    testWidgets('renders countdown timer when resend is locked', (
      tester,
    ) async {
      when(() => mockOtpCubit.state).thenReturn(
        const OtpState(secondsRemaining: 45),
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          const OtpVerificationPage(email: 'scholar@kortex.ai'),
        ),
      );
      await tester.pump();

      expect(find.text('Resend in 45s'), findsOneWidget);
    });

    testWidgets('renders resend code button when canResend is true', (
      tester,
    ) async {
      when(() => mockOtpCubit.state).thenReturn(
        const OtpState(canResend: true, secondsRemaining: 0),
      );

      await tester.pumpWidget(
        _wrapWithTheme(
          const OtpVerificationPage(email: 'scholar@kortex.ai'),
        ),
      );
      await tester.pump();

      expect(find.text('Resend Code'), findsOneWidget);
    });
  });
}
