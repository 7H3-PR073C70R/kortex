import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/deck_creation_action_sheet.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/deck_filter_chip.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/decks_empty_state_view.dart';
import 'package:kortex/src/features/decks/presentation/widgets/decks/decks_shimmer_skeleton.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Decks Sub-widgets Test Suite', () {
    testWidgets('DeckFilterChip renders label and triggers tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          DeckFilterChip(
            label: 'Due Cards',
            count: 7,
            isDueBadge: true,
            isSelected: true,
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Due Cards'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);

      await tester.tap(find.text('Due Cards'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('DeckActionOptionTile renders option details and handles click', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          DeckActionOptionTile(
            icon: Icons.layers_rounded,
            iconColor: Colors.amber,
            title: 'Custom Title',
            subtitle: 'Custom Subtitle description',
            onTap: () => tapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Title'), findsOneWidget);
      expect(find.text('Custom Subtitle description'), findsOneWidget);
      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);

      await tester.tap(find.text('Custom Title'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('DecksEmptyStateView renders due, mastered, and general empty state correctly', (tester) async {
      var createDeckTapped = false;
      var resetFilterTapped = false;

      // 1. Due empty state
      await tester.pumpWidget(
        createTestApp(
          DecksEmptyStateView(
            activeFilter: 'due',
            allDecks: const [
              DeckEntity(
                id: 'deck_1',
                title: 'Pathology',
                subject: 'PATH',
                totalCards: 20,
                dueCards: 0,
                masteryRate: 0.8,
                category: 'Medical',
              ),
            ],
            onCreateDeckTap: () => createDeckTapped = true,
            onResetFilterToAll: () => resetFilterTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('All Caught Up! 🎉'), findsOneWidget);
      expect(find.text('Review All Decks'), findsOneWidget);

      await tester.tap(find.text('Review All Decks'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(resetFilterTapped, isTrue);

      // 2. Mastered empty state
      await tester.pumpWidget(
        createTestApp(
          DecksEmptyStateView(
            activeFilter: 'mastered',
            allDecks: const [],
            onCreateDeckTap: () => createDeckTapped = true,
            onResetFilterToAll: () => resetFilterTapped = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('No Mastered Decks Yet 🎯'), findsOneWidget);
      expect(createDeckTapped, isFalse);
    });

    testWidgets('DecksShimmerSkeleton renders without errors', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const SizedBox(
            height: 600,
            child: DecksShimmerSkeleton(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DecksShimmerSkeleton), findsOneWidget);
    });
  });
}
