import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/onboarding/presentation/widgets/interactive_rocket_launch_overlay.dart';
import 'package:kortex/src/l10n/l10n.dart';

void main() {
  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('Interactive Rocket Launch Sub-Widgets', () {
    test('FlightParticle and models initialize with expected values', () {
      final particle = FlightParticle(
        x: 0.5,
        y: 0.5,
        vx: 0.1,
        vy: -0.2,
        radius: 3,
        color: Colors.amber,
        maxLife: 1,
      );
      expect(particle.x, equals(0.5));
      expect(particle.life, equals(1.0));
      expect(particle.isDead, isFalse);
      particle.life = 0;
      expect(particle.isDead, isTrue);

      final orb = KnowledgeOrb(
        symbol: 'AI',
        label: 'Syllabot',
        xRatio: 0.5,
        y: 100,
        color: Colors.cyan,
      );
      expect(orb.symbol, equals('AI'));
      expect(orb.isCollected, isFalse);

      final score = FloatingScore(
        text: '+50',
        x: 100,
        y: 200,
        color: Colors.green,
      );
      expect(score.text, equals('+50'));
    });

    testWidgets('CosmicFlightPainter paints on CustomPaint canvas', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          CustomPaint(
            size: const Size(400, 800),
            painter: CosmicFlightPainter(
              stars: const [Offset(50, 100), Offset(150, 200)],
              particles: [
                FlightParticle(
                  x: 0.5,
                  y: 0.8,
                  vx: 0,
                  vy: -0.5,
                  radius: 4,
                  color: Colors.orange,
                  maxLife: 1,
                ),
              ],
              machSpeed: 2.5,
              isWarping: false,
              warpProgress: 0,
              primaryColor: Colors.deepPurple,
              accentColor: Colors.cyanAccent,
              warningColor: Colors.amber,
              whiteColor: Colors.white,
              surfaceColor: Colors.black,
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('RocketShipPainter paints rocket on CustomPaint canvas', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          CustomPaint(
            size: const Size(300, 300),
            painter: RocketShipPainter(
              primaryColor: Colors.blue,
              accentColor: Colors.cyanAccent,
              whiteColor: Colors.white,
              warningColor: Colors.orange,
              isTurbo: true,
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('RocketLaunchHudBar displays telemetry and invokes onSkip', (tester) async {
      var skipped = false;

      await tester.pumpWidget(
        buildTestableWidget(
          RocketLaunchHudBar(
            machSpeed: 4.2,
            score: 150,
            isWarping: false,
            onSkip: () => skipped = true,
          ),
        ),
      );

      expect(find.textContaining('150'), findsOneWidget);

      final skipFinder = find.text('Skip');
      expect(skipFinder, findsOneWidget);
      await tester.tap(skipFinder);
      await tester.pump();
      expect(skipped, isTrue);
    });

    testWidgets('InteractiveRocketLaunchOverlay renders and mounts cleanly', (tester) async {
      var completed = false;

      await tester.pumpWidget(
        buildTestableWidget(
          InteractiveRocketLaunchOverlay(
            onLaunchComplete: () => completed = true,
          ),
        ),
      );

      expect(find.byType(InteractiveRocketLaunchOverlay), findsOneWidget);
      expect(find.byType(RocketLaunchHudBar), findsOneWidget);
      expect(completed, isFalse);

      // Tap skip button to complete launch
      final skipFinder = find.text('Skip');
      expect(skipFinder, findsOneWidget);
      await tester.tap(skipFinder);
      await tester.pump();
      expect(completed, isTrue);
    });
  });
}
