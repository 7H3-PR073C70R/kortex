import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/core/database/app_database.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_local_data_source_impl.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source_impl.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrofit/retrofit.dart';

class MockDecksApiClient extends Mock implements DecksApiClient {}

void main() {
  group('DecksLocalDataSourceImpl', () {
    late AppDatabase appDatabase;
    late DecksLocalDataSource localDataSource;

    setUp(() {
      appDatabase = AppDatabase(NativeDatabase.memory());
      localDataSource = DecksLocalDataSourceImpl(appDatabase);
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('saves and retrieves deck with its flashcards', () async {
      const deck = DeckModel(
        id: 'deck_abc',
        title: 'Organic Chemistry',
        subject: 'Chemistry',
        category: 'Science',
        totalCards: 2,
        dueCards: 2,
        masteryRate: 0,
      );

      final cards = [
        const FlashcardModel(
          id: 'c_1',
          deckId: 'deck_abc',
          front: 'Benzene formula',
          back: 'C6H6',
        ),
        const FlashcardModel(
          id: 'c_2',
          deckId: 'deck_abc',
          front: 'Methane formula',
          back: 'CH4',
        ),
      ];

      await localDataSource.saveDeck(deck, cards: cards);

      final loadedDecks = await localDataSource.getDecks();
      expect(loadedDecks.length, equals(1));
      expect(loadedDecks.first.id, equals('deck_abc'));
      expect(loadedDecks.first.title, equals('Organic Chemistry'));

      final loadedDeck = await localDataSource.getDeck('deck_abc');
      expect(loadedDeck, isNotNull);
      expect(loadedDeck!.cards.length, equals(2));
      expect(loadedDeck.cards.first.front, equals('Benzene formula'));
    });

    test('updateCard updates single card and triggers stats recalculation', () async {
      const deck = DeckModel(
        id: 'deck_single',
        title: 'Physics',
        subject: 'Physics',
        category: 'Science',
        totalCards: 1,
        dueCards: 1,
        masteryRate: 0,
      );

      const card = FlashcardModel(
        id: 'c_p1',
        deckId: 'deck_single',
        front: 'F = ma',
        back: "Newton's 2nd Law",
      );

      await localDataSource.saveDeck(deck, cards: [card]);

      // Update card after review
      final reviewedCard = card.copyWith(
        repetitions: 1,
        lastReviewed: DateTime.now(),
        nextDueDate: DateTime.now().add(const Duration(days: 3)),
      );
      await localDataSource.updateCard(reviewedCard);

      final updatedCards = await localDataSource.getCardsForDeck('deck_single');
      expect(updatedCards.length, equals(1));
      expect(updatedCards.first.repetitions, equals(1));
      expect(updatedCards.first.nextDueDate, isNotNull);

      final updatedDeck = await localDataSource.getDeck('deck_single');
      expect(updatedDeck, isNotNull);
      expect(updatedDeck!.masteryRate, equals(1));
      expect(updatedDeck.dueCards, equals(0));
    });

    test('linkDeckToCourse updates course fields without modifying cards', () async {
      const deck = DeckModel(
        id: 'deck_course_test',
        title: 'Microbiology',
        subject: 'Biology',
        category: 'Science',
        totalCards: 0,
        dueCards: 0,
        masteryRate: 0,
      );

      await localDataSource.saveDeck(deck);

      await localDataSource.linkDeckToCourse(
        deckId: 'deck_course_test',
        courseId: 'course_bio_202',
        courseCode: 'BIO202',
        subject: 'Microbiology',
      );

      final updated = await localDataSource.getDeck('deck_course_test');
      expect(updated, isNotNull);
      expect(updated!.courseId, equals('course_bio_202'));
      expect(updated.courseCode, equals('BIO202'));
    });
  });

  group('DecksRemoteDataSourceImpl with DecksLocalDataSource', () {
    late AppDatabase appDatabase;
    late DecksLocalDataSource localDataSource;
    late MockDecksApiClient mockApiClient;
    late DecksRemoteDataSourceImpl remoteDataSource;

    setUp(() {
      appDatabase = AppDatabase(NativeDatabase.memory());
      localDataSource = DecksLocalDataSourceImpl(appDatabase);
      mockApiClient = MockDecksApiClient();

      remoteDataSource = DecksRemoteDataSourceImpl(
        mockApiClient,
        localDataSource: localDataSource,
      );
    });

    tearDown(() async {
      await appDatabase.close();
    });

    test('saveSessionResults performs targeted card & stats updates without monolithic re-serialization', () async {
      when(() => mockApiClient.saveSessionResults(any())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          {'success': true},
          Response(requestOptions: RequestOptions()),
        ),
      );
      when(() => mockApiClient.updateDeckRecord(any(), any())).thenAnswer(
        (_) async => HttpResponse<dynamic>(
          {'success': true},
          Response(requestOptions: RequestOptions()),
        ),
      );

      const deck = DeckModel(
        id: 'session_deck',
        title: 'History',
        subject: 'History',
        category: 'Humanities',
        totalCards: 2,
        dueCards: 2,
        masteryRate: 0,
      );

      final initialCards = [
        const FlashcardModel(
          id: 'card_h1',
          deckId: 'session_deck',
          front: 'WWII End',
          back: '1945',
        ),
        const FlashcardModel(
          id: 'card_h2',
          deckId: 'session_deck',
          front: 'Magna Carta',
          back: '1215',
        ),
      ];

      await localDataSource.saveDeck(deck, cards: initialCards);

      final updatedCards = [
        initialCards[0].copyWith(
          repetitions: 1,
          lastReviewed: DateTime.now(),
          nextDueDate: DateTime.now().add(const Duration(days: 4)),
        ),
      ];

      await remoteDataSource.saveSessionResults(
        deckId: 'session_deck',
        cardsReviewed: 1,
        durationSeconds: 45,
        retentionScore: 1,
        masteryRate: 0.5,
        dueCards: 1,
        updatedCards: updatedCards,
      );

      // Verify card was updated in SQLite
      final cardsInDb = await localDataSource.getCardsForDeck('session_deck');
      final updatedCardInDb = cardsInDb.firstWhere((c) => c.id == 'card_h1');
      expect(updatedCardInDb.repetitions, equals(1));

      // Verify deck stats were updated in SQLite
      final deckInDb = await localDataSource.getDeck('session_deck');
      expect(deckInDb, isNotNull);
      expect(deckInDb!.masteryRate, equals(0.5));
      expect(deckInDb.dueCards, equals(1));
    });
  });
}
