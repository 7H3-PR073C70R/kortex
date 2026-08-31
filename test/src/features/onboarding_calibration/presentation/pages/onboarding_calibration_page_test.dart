import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/save_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/bloc/calibration_cubit.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/pages/onboarding_calibration_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockSaveCalibrationProfileUseCase extends Mock
    implements SaveCalibrationProfileUseCase {}

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
  late MockSaveCalibrationProfileUseCase mockSaveUseCase;

  setUpAll(() {
    registerFallbackValue(const CalibrationProfile());
  });

  setUp(() async {
    mockSaveUseCase = MockSaveCalibrationProfileUseCase();
    when(() => mockSaveUseCase(any()))
        .thenAnswer((_) async => const Right(null));

    final locator = GetIt.instance;
    if (locator.isRegistered<CalibrationCubit>()) {
      await locator.unregister<CalibrationCubit>();
    }
    locator.registerFactory<CalibrationCubit>(
      () => CalibrationCubit(
        saveCalibrationProfileUseCase: mockSaveUseCase,
      ),
    );
  });

  group('OnboardingCalibrationPage Test Suite', () {
    testWidgets('renders step 1 Question 1 initially', (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingCalibrationPage()),
      );
      await tester.pump();

      expect(
        find.text('What is your current academic focus?'),
        findsOneWidget,
      );
      expect(find.text('University / Polytechnic'), findsOneWidget);
      expect(find.text('High School / Exam Prep'), findsOneWidget);
    });

    testWidgets('selecting Higher Education branch navigates to Step A2',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingCalibrationPage()),
      );
      await tester.pump();

      // Tap Continue to go to Step A2
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(
        find.text('What is your current academic level?'),
        findsOneWidget,
      );
      expect(find.text('BSc (Bachelor of Science)'), findsOneWidget);
    });

    testWidgets('selecting High School branch navigates to Step B2',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingCalibrationPage()),
      );
      await tester.pump();

      // Select High School chip
      await tester.tap(find.text('High School / Exam Prep'));
      await tester.pump();

      // Tap Continue to go to Step B2
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 450));

      expect(
        find.text('What exam are you preparing for?'),
        findsOneWidget,
      );
      expect(find.text('JAMB / UTME'), findsOneWidget);
      expect(find.text('WAEC / GCE'), findsOneWidget);
    });

    testWidgets('renders desktop split layout on width >= 1024',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingCalibrationPage()),
      );
      await tester.pump();

      expect(
        find.text('Calibrating Neural Learning Engine'),
        findsOneWidget,
      );
      expect(
        find.text('Adaptive RAG Knowledge Base'),
        findsOneWidget,
      );
    });
  });
}
