import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:retrofit/retrofit.dart';

part 'past_questions_api_client.g.dart';

@RestApi()
abstract class PastQuestionsApiClient {
  factory PastQuestionsApiClient(Dio dio, {String baseUrl}) =
      _PastQuestionsApiClient;

  @GET(AppApiEndpoint.pastQuestions)
  Future<HttpResponse<dynamic>> fetchPastQuestions(
    @Queries() Map<String, dynamic> query,
  );
}
