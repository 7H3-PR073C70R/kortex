import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/decks/presentation/pages/create_deck_page.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_ai_generator_tab.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_cards_river.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_details_card.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/create_deck_manual_entry_tab.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/draft_card.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksRepository extends Mock implements DecksRepository {}
class FakeDeckEntity extends Fake implements DeckEntity {}
class FakeFlashcardEntity extends Fake implements FlashcardEntity {}

Widget createTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeDeckEntity());
    registerFallbackValue(FakeFlashcardEntity());
  });

  group('CreateDeck Details & Tab Sub-widgets Tests', () {
    testWidgets('CreateDeckDetailsCard renders title, desc fields and course badge', (tester) async {
      final titleCtrl = TextEditingController(text: 'CSC301 Flashcards');
      final descCtrl = TextEditingController(text: 'Operating Systems recall');

      await tester.pumpWidget(
        createTestApp(
          CreateDeckDetailsCard(
            titleController: titleCtrl,
            descController: descCtrl,
            courseCode: 'CSC301',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deck Details'), findsOneWidget);
      expect(find.text('CSC301'), findsOneWidget);
      expect(find.text('CSC301 Flashcards'), findsOneWidget);
      expect(find.text('Operating Systems recall'), findsOneWidget);
    });

    testWidgets('CreateDeckManualEntryTab captures input and calls onAddCard', (tester) async {
      final frontCtrl = TextEditingController();
      final backCtrl = TextEditingController();
      var addCalled = false;

      await tester.pumpWidget(
        createTestApp(
          CreateDeckManualEntryTab(
            frontController: frontCtrl,
            backController: backCtrl,
            onAddCard: () => addCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Semaphores');
      await tester.enterText(find.byType(TextField).last, 'Synchronization tool');
      await tester.tap(find.text('+ Add Flashcard'));
      await tester.pumpAndSettle();

      expect(addCalled, isTrue);
    });

    testWidgets('CreateDeckAiGeneratorTab allows selecting card counts and triggers generate', (tester) async {
      final topicCtrl = TextEditingController(text: 'Virtual Memory');
      var currentCount = 10;
      var generateCalled = false;

      await tester.pumpWidget(
        createTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return CreateDeckAiGeneratorTab(
                topicController: topicCtrl,
                cardCount: currentCount,
                onCardCountChanged: (val) {
                  setState(() => currentCount = val);
                },
                isGenerating: false,
                onGenerate: () => generateCalled = true,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Flashcard Generator'), findsOneWidget);
      expect(find.text('Virtual Memory'), findsOneWidget);

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      expect(currentCount, equals(20));

      await tester.tap(find.text('✨ Generate & Add Cards'));
      expect(generateCalled, isTrue);
    });

    testWidgets('CreateDeckCardsRiver renders draft cards and handles delete and clear', (tester) async {
      var cards = [
        const DraftCard(front: 'Card 1 Front', back: 'Card 1 Back'),
        const DraftCard(front: 'Card 2 Front', back: 'Card 2 Back'),
      ];
      var clearCalled = false;
      int? deletedIndex;

      await tester.pumpWidget(
        createTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              return CreateDeckCardsRiver(
                cards: cards,
                onClearAll: () {
                  clearCalled = true;
                  setState(() => cards = []);
                },
                onDeleteCard: (index) {
                  deletedIndex = index;
                  setState(() => cards.removeAt(index));
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cards in Deck (2)'), findsOneWidget);
      expect(find.text('Card 1 Front'), findsOneWidget);
      expect(find.text('Card 2 Front'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pumpAndSettle();
      expect(deletedIndex, equals(0));
      expect(find.text('Cards in Deck (1)'), findsOneWidget);

      await tester.tap(find.text('Clear All'));
      await tester.pumpAndSettle();
      expect(clearCalled, isTrue);
      expect(find.text('No flashcards in this deck yet'), findsOneWidget);
    });
  });

  group('CreateDeckPage Integration Flow Tests', () {
    testWidgets('CreateDeckPage renders full layout and adds manual flashcards', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = MockDecksRepository();
      when(
        () => mockRepo.saveGeneratedDeck(
          deck: any(named: 'deck'),
          cards: any(named: 'cards'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        createTestApp(
          CreateDeckPage(
            courseCode: 'BIO101',
            courseTitle: 'General Biology',
            decksRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Study Deck'), findsWidgets);
      expect(find.text('BIO101'), findsOneWidget);
      expect(find.text('Cards in Deck (0)'), findsOneWidget);

      // Add a manual card
      final textFields = find.byType(TextField);
      // TextField 0: Deck Name, TextField 1: Description, TextField 2: Front, TextField 3: Back
      await tester.enterText(textFields.at(2), 'What is Mitosis?');
      await tester.enterText(textFields.at(3), 'Cell division resulting in two daughter cells.');
      await tester.tap(find.text('+ Add Flashcard'));
      await tester.pumpAndSettle();

      expect(find.text('Cards in Deck (1)'), findsOneWidget);
      expect(find.text('What is Mitosis?'), findsOneWidget);
      expect(find.text('Cell division resulting in two daughter cells.'), findsOneWidget);
      expect(find.text('Create Deck (1 Cards)'), findsOneWidget);
    });
  });
}
