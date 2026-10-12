import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/themes/app_theme.dart';
import 'package:kortex/src/core/utils/either.dart';
import 'package:kortex/src/features/community/domain/entities/forum_post_entity.dart';
import 'package:kortex/src/features/community/presentation/widgets/forum_flashcard_sheets.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/decks/domain/repositories/decks_repository.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/domain/use_cases/stream_syllabot_response_use_case.dart';
import 'package:kortex/src/l10n/arb/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockDecksRepository extends Mock implements DecksRepository {}
class MockStreamSyllabotResponseUseCase extends Mock implements StreamSyllabotResponseUseCase {}
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
    registerFallbackValue(SocraticMode.directAnswer);
    registerFallbackValue(ExecutionEngineType.cloudRemote);
  });

  final dummyPost = ForumPostEntity(
    id: 'post_101',
    authorId: 'user_1',
    authorName: 'Ada Lovelace',
    track: 'Computer Science',
    title: 'How does Dijkstra algorithm work?',
    content: 'Can someone explain the greedy choice property in Dijkstra algorithm?',
    syllabusTag: 'Algorithms',
    createdAt: DateTime.now(),
  );

  final dummyReply = ForumReplyEntity(
    id: 'reply_201',
    postId: 'post_101',
    authorId: 'user_2',
    authorName: 'Alan Turing',
    content: 'It greedily selects the unvisited node with the smallest distance value.',
    createdAt: DateTime.now(),
    isVerifiedSolution: true,
  );

  group('ForumDeckAiParser Unit Tests', () {
    test('buildPrompt formats post and replies into structured prompt', () {
      final prompt = ForumDeckAiParser.buildPrompt(
        post: dummyPost,
        replies: [dummyReply],
        topicTag: 'Algorithms',
      );

      expect(prompt, contains('Discussion Title: How does Dijkstra algorithm work?'));
      expect(prompt, contains('Subject / Topic: Algorithms'));
      expect(prompt, contains('Q: Can someone explain the greedy choice property'));
      expect(prompt, contains('A (by @Alan Turing)'));
      expect(prompt, contains('Return ONLY valid JSON'));
    });

    test('parseCardsJson parses valid JSON response into cards list', () {
      const sampleJson = '''
[
  {"front": "What is Dijkstra's algorithm?", "back": "A shortest path graph algorithm."},
  {"front": "What is the time complexity with min-heap?", "back": "O((V + E) log V)."}
]
''';
      final cards = ForumDeckAiParser.parseCardsJson(sampleJson);

      expect(cards.length, equals(2));
      expect(cards[0].front, equals("What is Dijkstra's algorithm?"));
      expect(cards[0].back, equals('A shortest path graph algorithm.'));
      expect(cards[1].front, equals('What is the time complexity with min-heap?'));
      expect(cards[1].back, equals('O((V + E) log V).'));
    });

    test('parseCardsJson handles empty or malformed strings gracefully', () {
      expect(ForumDeckAiParser.parseCardsJson('[]'), isEmpty);
      expect(ForumDeckAiParser.parseCardsJson('random string'), isEmpty);
    });
  });

  group('SaveFlashcardCardPreview & Hints Tests', () {
    testWidgets('SaveFlashcardCardPreview renders Front and Back content', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const SaveFlashcardCardPreview(
            frontText: 'Front Question Sample',
            backText: 'Back Answer Sample',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('Front Question Sample'), findsOneWidget);
      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('Back Answer Sample'), findsOneWidget);
    });
  });

  group('ForumSaveFlashcardSheet Widget Tests', () {
    testWidgets('loads decks and renders options with save button', (tester) async {
      final mockRepo = MockDecksRepository();
      const testDeck = DeckEntity(
        id: 'deck_algos',
        title: 'Algorithms & Data Structures',
        subject: 'Algorithms',
        totalCards: 12,
        dueCards: 2,
        masteryRate: 0.8,
        category: 'Core',
      );

      when(mockRepo.getUserDecks)
          .thenAnswer((_) async => const Right([testDeck]));
      when(() => mockRepo.getDeckCards('deck_algos'))
          .thenAnswer((_) async => const Right([]));
      when(() => mockRepo.updateDeckCards(any(), any()))
          .thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        createTestApp(
          ForumSaveFlashcardSheet(
            post: dummyPost,
            reply: dummyReply,
            decksRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Save to Flashcard'), findsOneWidget);
      expect(find.text('Algorithms & Data Structures'), findsWidgets);
      expect(find.text('Save to "Algorithms & Data Structures"'), findsOneWidget);

      await tester.tap(find.text('Save to "Algorithms & Data Structures"'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.updateDeckCards('deck_algos', any())).called(1);
    });
  });

  group('ForumGenerateDeckSheet Widget Tests', () {
    testWidgets('renders prompt trigger and generates flashcards with AI stream', (tester) async {
      final mockStream = MockStreamSyllabotResponseUseCase();
      final mockRepo = MockDecksRepository();

      when(
        () => mockStream.call(
          prompt: any(named: 'prompt'),
          sessionId: any(named: 'sessionId'),
          socraticMode: any(named: 'socraticMode'),
          preferredEngine: any(named: 'preferredEngine'),
        ),
      ).thenAnswer(
        (_) => Stream.fromIterable([
          '[\n{"front": "Dijkstra Core", ',
          '"back": "Greedy choice selection."}\n]',
        ]),
      );

      when(
        () => mockRepo.saveGeneratedDeck(
          deck: any(named: 'deck'),
          cards: any(named: 'cards'),
        ),
      ).thenAnswer((_) async => const Right(null));

      await tester.pumpWidget(
        createTestApp(
          ForumGenerateDeckSheet(
            post: dummyPost,
            replies: [dummyReply],
            streamSyllabotResponseUseCase: mockStream,
            decksRepository: mockRepo,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Generate Flashcard Deck'), findsOneWidget);
      expect(find.text('Generate Flashcards with Syllabot'), findsOneWidget);

      await tester.tap(find.text('Generate Flashcards with Syllabot'));
      await tester.pumpAndSettle();

      expect(find.text('1 flashcards generated'), findsOneWidget);
      expect(find.text('1. Dijkstra Core'), findsOneWidget);
      expect(find.text('Greedy choice selection.'), findsOneWidget);
      expect(find.text('Save Deck (1 cards)'), findsOneWidget);

      await tester.tap(find.text('Save Deck (1 cards)'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.saveGeneratedDeck(deck: any(named: 'deck'), cards: any(named: 'cards'))).called(1);
    });
  });
}
