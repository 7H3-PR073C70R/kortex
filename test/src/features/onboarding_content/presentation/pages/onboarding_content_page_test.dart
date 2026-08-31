import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/core/utils/use_case.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/entities/calibration_profile.dart';
import 'package:kortex/src/features/onboarding_calibration/domain/use_cases/get_calibration_profile_use_case.dart';
import 'package:kortex/src/features/onboarding_content/domain/entities/recommended_content_item.dart';
import 'package:kortex/src/features/onboarding_content/domain/use_cases/get_recommended_content_use_case.dart';
import 'package:kortex/src/features/onboarding_content/presentation/bloc/content_recommendation_cubit.dart';
import 'package:kortex/src/features/onboarding_content/presentation/pages/onboarding_content_page.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';

class MockGetRecommendedContentUseCase extends Mock
    implements GetRecommendedContentUseCase {}

class MockGetCalibrationProfileUseCase extends Mock
    implements GetCalibrationProfileUseCase {}

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
  late MockGetRecommendedContentUseCase mockGetContentUseCase;
  late MockGetCalibrationProfileUseCase mockGetProfileUseCase;

  const testItems = [
    RecommendedContentItem(
      id: 'rec_1',
      type: RecommendationType.pastPapers,
      badge: 'DATABASE PRE-POPULATED',
      tagline: 'Instant Exam Readiness',
      description: 'Selected past papers for WAEC and JAMB.',
      formulaChips: ['JAMB / UTME', r'\int e^{-x^2} dx'],
    ),
    RecommendedContentItem(
      id: 'rec_2',
      type: RecommendationType.flashcards,
      badge: 'ACTIVE RECALL DECK',
      tagline: 'Deep Mastery of Mathematics',
      description: 'Structured flashcards for core topics.',
      formulaChips: ['SM-2 Active Recall'],
    ),
  ];

  setUpAll(() {
    registerFallbackValue(const NoParams());
    registerFallbackValue(
      GetRecommendationsParams(
        profile: const CalibrationProfile(),
        localizeHandler: (key, params) => '',
      ),
    );
  });

  setUp(() async {
    mockGetContentUseCase = MockGetRecommendedContentUseCase();
    mockGetProfileUseCase = MockGetCalibrationProfileUseCase();

    when(() => mockGetProfileUseCase(const NoParams()))
        .thenAnswer((_) async => const Right(CalibrationProfile()));
    when(() => mockGetContentUseCase(any()))
        .thenAnswer((_) async => const Right(testItems));

    final locator = GetIt.instance;
    if (locator.isRegistered<ContentRecommendationCubit>()) {
      await locator.unregister<ContentRecommendationCubit>();
    }
    locator.registerFactory<ContentRecommendationCubit>(
      () => ContentRecommendationCubit(
        getRecommendedContentUseCase: mockGetContentUseCase,
        getCalibrationProfileUseCase: mockGetProfileUseCase,
      ),
    );
  });

  group('OnboardingContentPage Test Suite', () {
    testWidgets('renders first recommendation item initially',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingContentPage()),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(find.text('Instant Exam Readiness'), findsOneWidget);
      expect(find.text('DATABASE PRE-POPULATED'), findsOneWidget);
      expect(find.text('KORTEX'), findsOneWidget);
    });

    testWidgets('tapping forward button advances to next recommendation',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingContentPage()),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      // Tap forward button
      await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.text('Deep Mastery of Mathematics'), findsOneWidget);
      expect(find.text('ACTIVE RECALL DECK'), findsOneWidget);
    });

    testWidgets('renders desktop split layout on width >= 1024',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _wrapWithTheme(const OnboardingContentPage()),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(
        find.text('Your Pre-Loaded Academic Hub'),
        findsOneWidget,
      );
      expect(
        find.text('Pre-indexed exam question banks'),
        findsOneWidget,
      );
    });
  });
}
