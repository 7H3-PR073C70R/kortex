import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kortex/src/features/decks/data/client/decks_api_client.dart';
import 'package:kortex/src/features/decks/data/data_sources/decks_remote_data_source_impl.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:retrofit/retrofit.dart';

class MockDecksApiClient implements DecksApiClient {
  Map<String, dynamic>? lastSessionPayload;
  String? lastUpdatedDeckId;
  Map<String, dynamic>? lastUpdatedDeckPayload;

  @override
  Future<HttpResponse<dynamic>> saveSessionResults(Map<String, dynamic> body) async {
    lastSessionPayload = body;
    return HttpResponse(
      {'success': true},
      Response(requestOptions: RequestOptions()),
    );
  }

  @override
  Future<HttpResponse<dynamic>> updateDeckRecord(String id, Map<String, dynamic> body) async {
    lastUpdatedDeckId = id;
    lastUpdatedDeckPayload = body;
    return HttpResponse(
      {'success': true},
      Response(requestOptions: RequestOptions()),
    );
  }

  @override
  Future<List<DeckModel>> getUserDecks() async {
    return [
      const DeckModel(
        id: 'deck-123',
        title: 'Biology 101',
        subject: 'Science',
        category: 'General',
        totalCards: 14,
        dueCards: 14,
        masteryRate: 0,
      ),
    ];
  }

  @override
  Future<List<FlashcardModel>> getDeckCards(String deckId) async => [];

  @override
  Future<HttpResponse<dynamic>> bulkInsertCards(dynamic body, {String prefer = 'return=representation'}) async {
    return HttpResponse(<String, dynamic>{}, Response(requestOptions: RequestOptions()));
  }

  @override
  Future<HttpResponse<dynamic>> createDeckRecord(Map<String, dynamic> body, {String prefer = 'return=representation'}) async {
    return HttpResponse(<String, dynamic>{}, Response(requestOptions: RequestOptions()));
  }

  @override
  Future<HttpResponse<dynamic>> deleteDeck(String id) async {
    return HttpResponse(<String, dynamic>{}, Response(requestOptions: RequestOptions()));
  }

  @override
  Future<HttpResponse<dynamic>> processCardReview(String cardId, Map<String, dynamic> body) async {
    return HttpResponse(<String, dynamic>{}, Response(requestOptions: RequestOptions()));
  }
}

void main() {
  group('Study Session Mastery & RPC Sync Test Suite', () {
    late MockDecksApiClient mockClient;
    late DecksRemoteDataSourceImpl dataSource;

    setUp(() {
      mockClient = MockDecksApiClient();
      dataSource = DecksRemoteDataSourceImpl(mockClient);
    });

    test('calculates deck mastery, updates due cards, and sends exact RPC parameter keys', () async {
      const deckId = 'deck-123';

      // 1. Initial deck has 0% mastery
      final initialDecks = await dataSource.getUserDecks();
      expect(initialDecks.first.masteryRate, 0.0);
      expect(initialDecks.first.dueCards, 14);

      // 2. Complete a 14-card study session
      await dataSource.saveSessionResults(
        deckId: deckId,
        cardsReviewed: 14,
        durationSeconds: 90,
        retentionScore: 0.85,
      );

      // 3. Verify RPC payload keys
      expect(mockClient.lastSessionPayload, isNotNull);
      expect(mockClient.lastSessionPayload!['p_deck_id'], deckId);
      expect(mockClient.lastSessionPayload!['p_cards_reviewed'], 14);
      expect(mockClient.lastSessionPayload!['p_duration_seconds'], 90);
      expect(mockClient.lastSessionPayload!['p_retention_score'], 0.85);

      // 4. Verify PATCH payload keys on public.decks
      expect(mockClient.lastUpdatedDeckId, deckId);
      expect(mockClient.lastUpdatedDeckPayload, isNotNull);
      expect(mockClient.lastUpdatedDeckPayload!['mastery_rate'], greaterThan(0.0));
      expect(mockClient.lastUpdatedDeckPayload!['due_cards'], 0);
      expect(mockClient.lastUpdatedDeckPayload!['last_studied'], isNotNull);

      // 5. Verify local deck reflection in getUserDecks()
      final updatedDecks = await dataSource.getUserDecks();
      expect(updatedDecks.first.masteryRate, greaterThan(0.0));
      expect(updatedDecks.first.dueCards, 0);
      expect(updatedDecks.first.lastStudied, isNotNull);
    });
  });
}
