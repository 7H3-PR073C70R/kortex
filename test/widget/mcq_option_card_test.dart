import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/mcq_option_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('McqOptionCard Widget Test Suite', () {
    testWidgets('idle option renders prefix and text, and is tappable', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Gibbs Free Energy',
            index: 0, // Option A
            state: McqOptionState.idle,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
      expect(find.text('Gibbs Free Energy'), findsOneWidget);

      await tester.tap(find.byType(McqOptionCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('pending selection is still tappable so it can be changed', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Staged Answer',
            index: 1, // Option B
            state: McqOptionState.selected,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.byType(McqOptionCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('correct reveal shows a check and disables taps', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Correct Answer',
            index: 1, // Option B
            state: McqOptionState.correctReveal,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.byType(McqOptionCard));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('wrong reveal shows a cancel mark and disables taps', (
      tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Wrong Answer',
            index: 2, // Option C
            state: McqOptionState.wrongReveal,
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      await tester.tap(find.byType(McqOptionCard));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('muted option renders without a verdict mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestApp(
          McqOptionCard(
            optionText: 'Eliminated Option',
            index: 3, // Option D
            state: McqOptionState.muted,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('D'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    });

    test('resolveState maps raw session flags to the right visual state', () {
      expect(
        McqOptionCard.resolveState(
          isSelected: false,
          isAnswered: false,
          isCorrect: false,
        ),
        McqOptionState.idle,
      );
      expect(
        McqOptionCard.resolveState(
          isSelected: true,
          isAnswered: false,
          isCorrect: false,
        ),
        McqOptionState.selected,
      );
      expect(
        McqOptionCard.resolveState(
          isSelected: true,
          isAnswered: true,
          isCorrect: true,
        ),
        McqOptionState.correctReveal,
      );
      expect(
        McqOptionCard.resolveState(
          isSelected: true,
          isAnswered: true,
          isCorrect: false,
        ),
        McqOptionState.wrongReveal,
      );
      expect(
        McqOptionCard.resolveState(
          isSelected: false,
          isAnswered: true,
          isCorrect: false,
        ),
        McqOptionState.muted,
      );
      expect(
        McqOptionCard.resolveState(
          isSelected: false,
          isAnswered: false,
          isCorrect: false,
          isEliminated: true,
        ),
        McqOptionState.muted,
      );
    });
  });
}
