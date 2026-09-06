import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source_impl.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockDecksApiClient extends Mock implements DecksApiClient {}

class MockUserStorageService extends Mock implements UserStorageService {}

void main() {
  late MockDecksApiClient mockClient;
  late MockUserStorageService mockUserStorage;
  late DecksRemoteDataSourceImpl dataSource;

  setUp(() {
    mockClient = MockDecksApiClient();
    mockUserStorage = MockUserStorageService();
    dataSource = DecksRemoteDataSourceImpl(
      mockClient,
      userStorage: mockUserStorage,
    );

    when(() => mockUserStorage.getUserId()).thenReturn('user_123');
  });

  group('DecksRemoteDataSourceImpl.saveGeneratedDeck', () {
    test('saves deck & cards locally and calls Supabase endpoints', () async {
      const deck = DeckModel(
        id: 'deck_bio_101',
        title: 'Cellular Biology',
        subject: 'Biology',
        category: 'Document Ingestion',
        totalCards: 2,
        dueCards: 2,
        masteryRate: 0,
      );

      final cards = [
        const FlashcardModel(
          id: 'card_1',
          deckId: 'deck_bio_101',
          front: 'Mitosis',
          back: 'Cell division into 2 identical daughter cells',
        ),
        const FlashcardModel(
          id: 'card_2',
          deckId: 'deck_bio_101',
          front: 'Meiosis',
          back: 'Cell division reducing chromosomes by half',
        ),
      ];

      when(
        () => mockClient.createDeckRecord(any<Map<String, dynamic>>()),
      ).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          {'id': 'deck_bio_101'},
          Response(requestOptions: RequestOptions()),
        ),
      );

      when(() => mockClient.bulkInsertCards(any<dynamic>())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          [
            {'id': 'card_1'},
            {'id': 'card_2'},
          ],
          Response(requestOptions: RequestOptions()),
        ),
      );

      await dataSource.saveGeneratedDeck(deck: deck, cards: cards);

      // Verify local instant availability
      final userDecks = await dataSource.getUserDecks();
      expect(userDecks.any((d) => d.id == 'deck_bio_101'), isTrue);

      final deckCards = await dataSource.getDeckCards('deck_bio_101');
      expect(deckCards.length, 2);

      // Verify Supabase remote calls were executed with foreign keys
      verify(
        () => mockClient.createDeckRecord(
          any<Map<String, dynamic>>(
            that: isA<Map<String, dynamic>>().having(
              (m) => m['id'],
              'id',
              'deck_bio_101',
            ),
          ),
        ),
      ).called(1);

      verify(
        () => mockClient.bulkInsertCards(
          any<dynamic>(
            that: isA<List<Map<String, dynamic>>>().having(
              (list) => list.length,
              'length',
              2,
            ),
          ),
        ),
      ).called(1);
    });

    test(
      'deleteDeck removes deck and cards locally and calls remote API',
      () async {
        when(() => mockClient.deleteDeck(any())).thenAnswer(
          (_) async => HttpResponse<dynamic>(
            null,
            Response(requestOptions: RequestOptions()),
          ),
        );

        await dataSource.deleteDeck('deck_bio_101');

        final userDecks = await dataSource.getUserDecks();
        expect(userDecks.any((d) => d.id == 'deck_bio_101'), isFalse);
        verify(() => mockClient.deleteDeck('deck_bio_101')).called(1);
      },
    );

    test('updateDeckCards recalculates due cards and mastery correctly', () async {
      const deck = DeckModel(
        id: 'deck_math',
        title: 'Math',
        subject: 'Mathematics',
        category: 'General',
        totalCards: 2,
        dueCards: 2,
        masteryRate: 0,
      );

      final cards = [
        const FlashcardModel(
          id: 'm1',
          deckId: 'deck_math',
          front: '1+1',
          back: '2',
        ),
        const FlashcardModel(
          id: 'm2',
          deckId: 'deck_math',
          front: '2+2',
          back: '4',
        ),
      ];

      when(() => mockClient.createDeckRecord(any())).thenAnswer(
        (_) async => HttpResponse({'id': 'deck_math'}, Response(requestOptions: RequestOptions())),
      );
      when(() => mockClient.bulkInsertCards(any<dynamic>())).thenAnswer(
        (_) async => HttpResponse<dynamic>(<dynamic>[], Response(requestOptions: RequestOptions())),
      );

      await dataSource.saveGeneratedDeck(deck: deck, cards: cards);

      // Now review card 1 and 2 (nextDueDate in future)
      final reviewedCards = [
        cards[0].copyWith(
          repetitions: 1,
          lastReviewed: DateTime.now(),
          nextDueDate: DateTime.now().add(const Duration(days: 3)),
        ),
        cards[1].copyWith(
          repetitions: 1,
          lastReviewed: DateTime.now(),
          nextDueDate: DateTime.now().add(const Duration(days: 3)),
        ),
      ];

      await dataSource.updateDeckCards('deck_math', reviewedCards);

      final userDecks = await dataSource.getUserDecks();
      final updatedDeck = userDecks.firstWhere((d) => d.id == 'deck_math');
      expect(updatedDeck.dueCards, 0);
      expect(updatedDeck.masteryRate, 1.0);
      expect(updatedDeck.cards.first.repetitions, 1);
    });

    test('saveSessionResults with updatedCards sets dueCards to 0 when all cards are scheduled in future', () async {
      const deck = DeckModel(
        id: 'deck_physics',
        title: 'Physics',
        subject: 'Physics',
        category: 'General',
        totalCards: 2,
        dueCards: 2,
        masteryRate: 0,
      );

      final cards = [
        const FlashcardModel(id: 'p1', deckId: 'deck_physics', front: 'F', back: 'ma'),
        const FlashcardModel(id: 'p2', deckId: 'deck_physics', front: 'E', back: 'mc^2'),
      ];

      when(() => mockClient.createDeckRecord(any())).thenAnswer(
        (_) async => HttpResponse({'id': 'deck_physics'}, Response(requestOptions: RequestOptions())),
      );
      when(() => mockClient.bulkInsertCards(any<dynamic>())).thenAnswer(
        (_) async => HttpResponse<dynamic>(<dynamic>[], Response(requestOptions: RequestOptions())),
      );
      when(() => mockClient.saveSessionResults(any())).thenAnswer(
        (_) async => HttpResponse({'status': 'ok'}, Response(requestOptions: RequestOptions())),
      );
      when(() => mockClient.updateDeckRecord(any(), any())).thenAnswer(
        (_) async => HttpResponse({'status': 'ok'}, Response(requestOptions: RequestOptions())),
      );

      await dataSource.saveGeneratedDeck(deck: deck, cards: cards);

      final updatedCards = [
        cards[0].copyWith(repetitions: 1, lastReviewed: DateTime.now(), nextDueDate: DateTime.now().add(const Duration(days: 2))),
        cards[1].copyWith(repetitions: 1, lastReviewed: DateTime.now(), nextDueDate: DateTime.now().add(const Duration(days: 2))),
      ];

      await dataSource.saveSessionResults(
        deckId: 'deck_physics',
        cardsReviewed: 2,
        durationSeconds: 30,
        retentionScore: 1,
        updatedCards: updatedCards,
      );

      final userDecks = await dataSource.getUserDecks();
      final updatedDeck = userDecks.firstWhere((d) => d.id == 'deck_physics');
      expect(updatedDeck.dueCards, 0);
      expect(updatedDeck.masteryRate, 1.0);
    });
  });
}
