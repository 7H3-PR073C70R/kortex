import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/domain/entities/user_profile_entity.dart';
import 'package:kortex/src/features/auth/domain/use_cases/complete_onboarding_use_case.dart';
import 'package:kortex/src/features/auth/presentation/pages/conversational_onboarding_page.dart';
import 'package:kortex/src/features/auth/presentation/pages/onboarding_wrapper_page.dart';
import 'package:kortex/src/features/auth/presentation/pages/traditional_form_onboarding_page.dart';
import 'package:kortex/src/features/auth/presentation/widgets/onboarding_mode_toggle_bar.dart';
import 'package:kortex/src/features/dashboard/domain/entities/analytics_summary_entity.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/get_dashboard_feed_use_case.dart';
import 'package:kortex/src/features/dashboard/domain/use_cases/quick_start_mock_exam_use_case.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockCompleteOnboardingUseCase extends Mock
    implements CompleteOnboardingUseCase {}

class MockGetDashboardFeedUseCase extends Mock
    implements GetDashboardFeedUseCase {}

class MockQuickStartMockExamUseCase extends Mock
    implements QuickStartMockExamUseCase {}

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

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  late MockCompleteOnboardingUseCase mockCompleteOnboardingUseCase;
  late MockGetDashboardFeedUseCase mockGetDashboardFeedUseCase;
  late MockQuickStartMockExamUseCase mockQuickStartMockExamUseCase;

  const tProfile = UserProfileEntity(
    id: 'user_123',
    email: 'student@university.edu',
    targetTrack: 'JAMB',
    dailyCardTarget: 25,
    isOnboarded: true,
  );

  setUp(() {
    mockCompleteOnboardingUseCase = MockCompleteOnboardingUseCase();
    mockGetDashboardFeedUseCase = MockGetDashboardFeedUseCase();
    mockQuickStartMockExamUseCase = MockQuickStartMockExamUseCase();

    when(
      () => mockCompleteOnboardingUseCase(
        track: any(named: 'track'),
        dailyTarget: any(named: 'dailyTarget'),
        retentionBenchmark: any(named: 'retentionBenchmark'),
      ),
    ).thenAnswer((_) async => const Right(tProfile));

    when(() => mockGetDashboardFeedUseCase(any())).thenAnswer(
      (_) async => const Right(
        DashboardFeedEntity(
          calibrationProfile: CalibrationProfile(
            focus: AcademicFocus.highSchool,
            highSchoolExam: 'JAMB',
            isCalibrated: true,
          ),
          analyticsSummary: AnalyticsSummaryEntity(
            currentStreakDays: 5,
            longestStreakDays: 14,
            weeklyMinutesStudied: 120,
            overallRetentionRate: 0.88,
            totalCardsMastered: 85,
            heatMapData: [],
            xpPoints: 450,
            academicRank: 'Scholar I',
          ),
          dueStudyDecks: [],
          curatedCourses: [],
        ),
      ),
    );

    locator
      ..registerLazySingleton<CompleteOnboardingUseCase>(
        () => mockCompleteOnboardingUseCase,
      )
      ..registerLazySingleton<GetDashboardFeedUseCase>(
        () => mockGetDashboardFeedUseCase,
      )
      ..registerLazySingleton<QuickStartMockExamUseCase>(
        () => mockQuickStartMockExamUseCase,
      )
      ..registerLazySingleton<DashboardBloc>(
        () => DashboardBloc(
          getDashboardFeedUseCase: mockGetDashboardFeedUseCase,
          quickStartMockExamUseCase: mockQuickStartMockExamUseCase,
        ),
      );
  });

  tearDown(() async {
    await locator.reset();
  });

  group('OnboardingWrapperPage & Dual-Mode AI Onboarding Test Suite', () {
    testWidgets(
      'renders OnboardingModeToggleBar and '
      'ConversationalOnboardingPage initially',
      (tester) async {
        await tester.pumpWidget(_wrapWithTheme(const OnboardingWrapperPage()));
        await tester.pump();

        expect(find.byType(OnboardingModeToggleBar), findsOneWidget);
        expect(find.byType(ConversationalOnboardingPage), findsOneWidget);
        expect(find.byType(TraditionalFormOnboardingPage), findsNothing);
      },
    );

    testWidgets(
      'tapping Form View tab switches to TraditionalFormOnboardingPage',
      (tester) async {
        await tester.pumpWidget(_wrapWithTheme(const OnboardingWrapperPage()));
        await tester.pump();

        expect(find.byType(ConversationalOnboardingPage), findsOneWidget);

        // Tap the Form View toggle segment
        await tester.tap(find.text('Form View'));
        await tester.pumpAndSettle();

        expect(find.byType(TraditionalFormOnboardingPage), findsOneWidget);
        expect(find.byType(ConversationalOnboardingPage), findsNothing);
      },
    );
  });
}
