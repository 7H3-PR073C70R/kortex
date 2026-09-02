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

      when(() => mockClient.createDeckRecord(any<Map<String, dynamic>>()))
          .thenAnswer(
        (_) async => HttpResponse<dynamic>(
          {'id': 'deck_bio_101'},
          Response(requestOptions: RequestOptions()),
        ),
      );

      when(() => mockClient.bulkInsertCards(any<dynamic>())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          [{'id': 'card_1'}, {'id': 'card_2'}],
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
  });
}
