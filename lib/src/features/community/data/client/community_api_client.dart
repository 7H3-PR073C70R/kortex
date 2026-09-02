import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:retrofit/retrofit.dart';

part 'community_api_client.g.dart';

@RestApi()
abstract class CommunityApiClient {
  factory CommunityApiClient(Dio dio, {String baseUrl}) = _CommunityApiClient;

  @GET(AppApiEndpoint.studyRooms)
  Future<HttpResponse<dynamic>> fetchStudyRooms(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.studyRooms)
  Future<HttpResponse<dynamic>> createStudyRoom(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @GET(AppApiEndpoint.forumPosts)
  Future<HttpResponse<dynamic>> fetchForumPosts(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.forumPosts)
  Future<HttpResponse<dynamic>> createForumPost(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @POST(AppApiEndpoint.forumReplies)
  Future<HttpResponse<dynamic>> replyToForumPost(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @GET(AppApiEndpoint.sharedDecks)
  Future<HttpResponse<dynamic>> fetchSharedDecks(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.sharedDecks)
  Future<HttpResponse<dynamic>> publishDeck(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @POST(AppApiEndpoint.cloneSharedDeckRpc)
  Future<HttpResponse<dynamic>> cloneSharedDeck(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.leaderboards)
  Future<HttpResponse<dynamic>> fetchLeaderboards(
    @Queries() Map<String, dynamic> query,
  );

  @POST('/rpc/auto_provision_community_rpc')
  Future<HttpResponse<dynamic>> autoProvisionCommunity(
    @Body() Map<String, dynamic> body,
  );

  @GET('/study_communities')
  Future<HttpResponse<dynamic>> fetchCourseCommunityStats(
    @Queries() Map<String, dynamic> query,
  );

  @POST('/rest/v1/study_sessions')
  Future<HttpResponse<dynamic>> recordStudySession(
    @Body() Map<String, dynamic> body,
  );
}
