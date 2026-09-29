import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/cbt_readiness_impact_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/deck_list_tile_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleDeck = DeckEntity(
    id: 'deck_responsive_1',
    title: 'Advanced Organic Chemistry & Molecular Kinetics',
    subject: 'Chemistry',
    courseCode: 'CHM301',
    totalCards: 128,
    dueCards: 24,
    masteryRate: 0.82,
    category: 'Recall',
    description: 'Comprehensive study deck covering reaction mechanisms and catalysis.',
  );

  final viewports = <String, Size>{
    'Ultra-narrow 300px': const Size(300, 600),
    'Mobile 360px': const Size(360, 780),
    'Tablet 600px': const Size(600, 900),
    'Desktop 1024px': const Size(1024, 768),
  };

  group('Deck responsive zero-overflow viewport tests', () {
    for (final entry in viewports.entries) {
      final label = entry.key;
      final size = entry.value;

      testWidgets('DeckListTileCard renders without overflow on $label', (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_buildTestApp(const DeckListTileCard(deck: sampleDeck)));
        await tester.pumpAndSettle();

        expect(find.text('Advanced Organic Chemistry & Molecular Kinetics'), findsOneWidget);
        expect(find.text('24'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('CbtReadinessImpactCard renders without overflow on $label', (tester) async {
        tester.view.physicalSize = Size(size.width * 2, size.height * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _buildTestApp(
            const CbtReadinessImpactCard(
              cardsReviewed: 15,
              retentionScore: 0.88,
              examTitle: 'JAMB CBT',
              topicName: 'Stereochemistry & Reaction Kinetics',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('CBT READINESS INDEX'), findsOneWidget);
        expect(find.text('JAMB CBT'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
