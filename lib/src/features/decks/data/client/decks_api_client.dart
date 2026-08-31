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

  @GET(AppApiEndpoint.deckCards)
  Future<List<FlashcardModel>> getDeckCards(@Path('id') String deckId);

  @POST(AppApiEndpoint.reviewCard)
  Future<HttpResponse<dynamic>> processCardReview(
    @Path('cardId') String cardId,
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.sessionResults)
  Future<HttpResponse<dynamic>> saveSessionResults(
    @Path('id') String deckId,
    @Body() Map<String, dynamic> body,
  );
}
