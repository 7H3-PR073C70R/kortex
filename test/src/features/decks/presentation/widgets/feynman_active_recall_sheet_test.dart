import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/presentation/widgets/feynman_active_recall_sheet.dart';
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
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testCard = FlashcardEntity(
    id: 'card-123',
    deckId: 'deck-123',
    front: 'What is the primary function of Mitochondria?',
    back: 'Cellular respiration and ATP generation through oxidative phosphorylation.',
  );

  group('FeynmanActiveRecallSheet Widget Tests', () {
    testWidgets('renders title, prompt preview, and action buttons', (tester) async {
      var revealTapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  unawaited(
                    FeynmanActiveRecallSheet.show(
                      context,
                      card: testCard,
                      onRevealCard: () {
                        revealTapped = true;
                      },
                    ),
                  );
                },
                child: const Text('Open Sheet'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Feynman Active Recall Mode'), findsOneWidget);
      expect(find.text('What is the primary function of Mitochondria?'), findsOneWidget);
      expect(find.text('Reveal & Verify Answer'), findsOneWidget);

      await tester.tap(find.text('Reveal & Verify Answer'));
      await tester.pumpAndSettle();

      expect(revealTapped, isTrue);
    });
  });
}
