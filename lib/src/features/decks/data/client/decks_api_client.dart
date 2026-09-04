import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/decks/data/models/deck_model.dart';
import 'package:kortex/src/features/decks/data/models/flashcard_model.dart';
import 'package:retrofit/retrofit.dart';

part 'decks_api_client.g.dart';

@RestApi()
abstract class DecksApiClient {
  factory DecksApiClient(Dio dio, {String baseUrl}) = _DecksApiClient;

  @GET(AppApiEndpoint.decks)
  Future<List<DeckModel>> getUserDecks();

  @POST('/rest/v1/decks')
  Future<HttpResponse<dynamic>> createDeckRecord(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @POST('/rest/v1/flashcards')
  Future<HttpResponse<dynamic>> bulkInsertCards(
    @Body() dynamic body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @GET(AppApiEndpoint.deckCards)
  Future<List<FlashcardModel>> getDeckCards(@Path('id') String deckId);

  @POST(AppApiEndpoint.reviewCard)
  Future<HttpResponse<dynamic>> processCardReview(
    @Path('cardId') String cardId,
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.sessionResults)
  Future<HttpResponse<dynamic>> saveSessionResults(
    @Body() Map<String, dynamic> body,
  );

  @PATCH('/rest/v1/decks?id=eq.{id}')
  Future<HttpResponse<dynamic>> updateDeckRecord(
    @Path('id') String id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/rest/v1/decks?id=eq.{id}')
  Future<HttpResponse<dynamic>> deleteDeck(@Path('id') String id);
}
