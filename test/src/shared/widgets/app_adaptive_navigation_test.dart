import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_app_bar.dart';
import 'package:kortex/src/shared/widgets/app_back_button.dart';
import 'package:kortex/src/shared/widgets/app_breadcrumbs.dart';

Widget _wrapWithScreenSize({
  required Widget child,
  required Size screenSize,
}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: MediaQueryData(size: screenSize),
      child: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Adaptive Navigation & Breadcrumbs Suite', () {
    testWidgets(
      'AppBackButton.shouldShow returns true on mobile and false on desktop',
      (tester) async {
        late bool mobileResult;
        late bool desktopResult;

        // Mobile viewport: 390 x 844
        await tester.pumpWidget(
          _wrapWithScreenSize(
            screenSize: const Size(390, 844),
            child: Builder(
              builder: (context) {
                mobileResult = AppBackButton.shouldShow(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(mobileResult, isTrue);

        // Desktop viewport: 1280 x 800
        await tester.pumpWidget(
          _wrapWithScreenSize(
            screenSize: const Size(1280, 800),
            child: Builder(
              builder: (context) {
                desktopResult = AppBackButton.shouldShow(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(desktopResult, isFalse);
      },
    );

    testWidgets(
      'AppBreadcrumbs renders items, separator, and handles tap on interactive segments',
      (tester) async {
        var parentTapped = false;

        await tester.pumpWidget(
          _wrapWithScreenSize(
            screenSize: const Size(1280, 800),
            child: Scaffold(
              body: AppBreadcrumbs(
                items: [
                  AppBreadcrumbItem(
                    label: 'Decks',
                    onTap: () => parentTapped = true,
                  ),
                  const AppBreadcrumbItem(
                    label: 'Neuroanatomy 101',
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Decks'), findsOneWidget);
        expect(find.text('Neuroanatomy 101'), findsOneWidget);
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

        await tester.tap(find.text('Decks'));
        await tester.pumpAndSettle();
        expect(parentTapped, isTrue);
      },
    );

    testWidgets(
      'AppAdaptiveAppBar hides leading back button and shows breadcrumbs on desktop',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithScreenSize(
            screenSize: const Size(1280, 800),
            child: const Scaffold(
              appBar: AppAdaptiveAppBar(
                titleText: 'Detail Page',
                breadcrumbs: [
                  AppBreadcrumbItem(label: 'Home'),
                  AppBreadcrumbItem(label: 'Detail Page'),
                ],
              ),
              body: SizedBox.shrink(),
            ),
          ),
        );

        // On desktop, leading back button is suppressed
        expect(find.byType(AppBackButton), findsNothing);
        // Breadcrumbs are rendered
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Detail Page'), findsOneWidget);
      },
    );

    testWidgets(
      'AppAdaptiveAppBar shows leading back button and standard title on mobile',
      (tester) async {
        await tester.pumpWidget(
          _wrapWithScreenSize(
            screenSize: const Size(390, 844),
            child: const Scaffold(
              appBar: AppAdaptiveAppBar(
                titleText: 'Mobile Title',
                breadcrumbs: [
                  AppBreadcrumbItem(label: 'Home'),
                  AppBreadcrumbItem(label: 'Mobile Title'),
                ],
              ),
              body: SizedBox.shrink(),
            ),
          ),
        );

        // On mobile, leading back button is shown
        expect(find.byType(AppBackButton), findsOneWidget);
        // Standard title is shown
        expect(find.text('Mobile Title'), findsOneWidget);
      },
    );
  });
}
