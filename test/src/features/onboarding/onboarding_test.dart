import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/onboarding/data/datasources/onboarding_local_data_source.dart';
import 'package:kortex/src/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:kortex/src/features/onboarding/presentation/pages/splash_page.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/animated_page_indicator.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/onboarding_illustrations.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockLocalStorageService extends Mock implements LocalStorageService {}

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
