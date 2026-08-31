import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/dashboard/data/models/dashboard_feed_model.dart';
import 'package:kortex/src/features/dashboard/data/models/study_deck_model.dart';
import 'package:retrofit/retrofit.dart';

part 'dashboard_api_client.g.dart';

@RestApi()
abstract class DashboardApiClient {
  factory DashboardApiClient(Dio dio, {String baseUrl}) = _DashboardApiClient;

  @GET(AppApiEndpoint.dashboardFeed)
  Future<DashboardFeedModel> getDashboardFeed();

  @GET(AppApiEndpoint.dashboardReviewQueue)
  Future<List<StudyDeckModel>> getReviewQueue();

  @POST(AppApiEndpoint.dashboardStartExam)
  Future<HttpResponse<dynamic>> startMockExam(
    @Body() Map<String, dynamic> body,
  );
}
