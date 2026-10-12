import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:kortex/src/shared/widgets/guided_tour/spotlight_painter.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_guide_card.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_step_model.dart';
import 'package:kortex/src/shared/widgets/guided_tour/tour_steps_data.dart';

Widget _wrap(Widget child) {
  return ScreenUtilInit(
    designSize: const Size(375, 812),
    builder: (context, _) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Guided Tour Sub-Widgets Tests', () {
    test('buildTourSteps returns exactly 15 structured steps', () {
      final colors = AppThemeColorsExtension.dark();
      final steps = buildTourSteps(colors);

      expect(steps.length, equals(15));
      expect(steps.first.title, contains('Daily Streak'));
      expect(steps.last.title, contains('Retention Analytics'));
    });

    testWidgets(
        'TourStep resolves fallback geometry if target key is unbound',
        (tester) async {
      final step = TourStep(
        badge: 'TEST',
        title: 'Title',
        subtitle: 'Sub',
        description: 'Desc',
        proTip: 'Tip',
        icon: Icons.star,
        accentColor: Colors.blue,
        targetTabIndex: 0,
        targetKey: GlobalKey(),
      );

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              final rect = step.resolveTarget(
                context,
                const Size(1000, 800),
                const EdgeInsets.only(top: 40),
              );
              expect(rect.width, greaterThan(0));
              expect(rect.height, greaterThan(0));
              expect(rect.top, equals(64));
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('TourGuideCard renders step content and fires navigation callbacks',
        (tester) async {
      var nextFired = false;
      var backFired = false;
      var finishFired = false;

      final step = TourStep(
        badge: 'STEP 2 OF 15',
        title: 'Custom Title Here',
        subtitle: 'Custom Subtitle Here',
        description: 'Detailed explanation for this test step.',
        proTip: 'Pro-tip for test step.',
        icon: Icons.lightbulb,
        accentColor: Colors.amber,
        targetTabIndex: 1,
        targetKey: GlobalKey(),
      );

      await tester.pumpWidget(
        _wrap(
          TourGuideCard(
            step: step,
            currentStepIndex: 1,
            totalSteps: 15,
            isLastStep: false,
            cardMaxWidth: 400,
            cardMaxHeight: 600,
            onFinishTour: () => finishFired = true,
            onNextStep: () => nextFired = true,
            onPreviousStep: () => backFired = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Title Here'), findsOneWidget);
      expect(find.text('Custom Subtitle Here'), findsOneWidget);
      expect(find.text('STEP 2 OF 15'), findsOneWidget);
      expect(find.text('Pro-tip for test step.'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Next Step'), findsOneWidget);

      await tester.tap(find.text('Next Step'));
      await tester.pump();
      expect(nextFired, isTrue);

      await tester.tap(find.text('Back'));
      await tester.pump();
      expect(backFired, isTrue);

      await tester.tap(find.text('Skip Tour'));
      await tester.pump();
      expect(finishFired, isTrue);
    });

    testWidgets('TourGuideCard displays Start Learning on final step',
        (tester) async {
      final step = TourStep(
        badge: 'STEP 15 OF 15',
        title: 'Final Step',
        subtitle: 'Done',
        description: 'All done.',
        proTip: 'Enjoy!',
        icon: Icons.check,
        accentColor: Colors.green,
        targetTabIndex: 4,
        targetKey: GlobalKey(),
      );

      await tester.pumpWidget(
        _wrap(
          TourGuideCard(
            step: step,
            currentStepIndex: 14,
            totalSteps: 15,
            isLastStep: true,
            cardMaxWidth: 400,
            cardMaxHeight: 600,
            onFinishTour: () {},
            onNextStep: () {},
            onPreviousStep: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start Learning'), findsOneWidget);
      expect(find.text('Next Step'), findsNothing);
    });

    test('SpotlightPainter shouldRepaint triggers correctly', () {
      const painter1 = SpotlightPainter(
        targetRect: Rect.fromLTWH(10, 10, 50, 50),
        pulseValue: 0.5,
        accentColor: Colors.blue,
        scrimColor: Colors.black,
      );
      const painter2 = SpotlightPainter(
        targetRect: Rect.fromLTWH(10, 10, 50, 50),
        pulseValue: 0.8,
        accentColor: Colors.blue,
        scrimColor: Colors.black,
      );

      expect(painter1.shouldRepaint(painter2), isTrue);
      expect(painter1.shouldRepaint(painter1), isFalse);
    });
  });
}
