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

  @DELETE(AppApiEndpoint.forumPosts)
  Future<HttpResponse<dynamic>> deleteForumPost(
    @Queries() Map<String, dynamic> query,
  );

  @GET(AppApiEndpoint.forumReplies)
  Future<HttpResponse<dynamic>> fetchForumReplies(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.forumReplies)
  Future<HttpResponse<dynamic>> replyToForumPost(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @POST(AppApiEndpoint.verifyForumReplyRpc)
  Future<HttpResponse<dynamic>> verifyForumReply(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.voteForumPostAtomicRpc)
  Future<HttpResponse<dynamic>> voteForumPostAtomic(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.voteForumReplyAtomicRpc)
  Future<HttpResponse<dynamic>> voteForumReplyAtomic(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.toggleForumPostSubscriptionRpc)
  Future<HttpResponse<dynamic>> toggleForumPostSubscription(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.isForumPostSubscribedRpc)
  Future<HttpResponse<dynamic>> isForumPostSubscribed(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.fetchForumPostsKeysetRpc)
  Future<HttpResponse<dynamic>> fetchForumPostsKeyset(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.fetchForumThreadTreeRpc)
  Future<HttpResponse<dynamic>> fetchForumThreadTree(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.saveForumSocraticHintRpc)
  Future<HttpResponse<dynamic>> saveForumSocraticHint(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.forumPostSubscriptions)
  Future<HttpResponse<dynamic>> fetchForumPostSubscriptions(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.forumPostSubscriptions)
  Future<HttpResponse<dynamic>> insertForumPostSubscription(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'resolution=ignore-duplicates',
  });

  @DELETE(AppApiEndpoint.forumPostSubscriptions)
  Future<HttpResponse<dynamic>> deleteForumPostSubscription(
    @Queries() Map<String, dynamic> query,
  );

  @PATCH(AppApiEndpoint.forumReplies)
  Future<HttpResponse<dynamic>> updateForumReply(
    @Queries() Map<String, dynamic> query,
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @PATCH(AppApiEndpoint.forumPosts)
  Future<HttpResponse<dynamic>> updateForumPost(
    @Queries() Map<String, dynamic> query,
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @GET(AppApiEndpoint.studyCircles)
  Future<HttpResponse<dynamic>> fetchStudyCircles(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.studyCircles)
  Future<HttpResponse<dynamic>> createStudyCircle(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });

  @POST(AppApiEndpoint.studyCircleMembers)
  Future<HttpResponse<dynamic>> joinStudyCircle(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'resolution=ignore-duplicates,return=representation',
  });

  @DELETE(AppApiEndpoint.studyCircleMembers)
  Future<HttpResponse<dynamic>> leaveStudyCircle(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.nudgeStudyCircleRpc)
  @Extra({'silent': true})
  Future<HttpResponse<dynamic>> nudgeStudyCircle(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.recordPodFocusMinutesRpc)
  @Extra({'silent': true})
  Future<HttpResponse<dynamic>> recordPodFocusMinutes(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.notifications)
  @Extra({'silent': true})
  Future<HttpResponse<dynamic>> createNotification(
    @Body() Map<String, dynamic> body,
  );

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

  @POST(AppApiEndpoint.rateSharedDeckRpc)
  Future<HttpResponse<dynamic>> rateSharedDeck(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.leaderboards)
  Future<HttpResponse<dynamic>> fetchLeaderboards(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.claimWeeklyXpRpc)
  Future<HttpResponse<dynamic>> claimWeeklyXp(
    @Body() Map<String, dynamic> body,
  );

  @POST(AppApiEndpoint.autoProvisionCommunityRpc)
  Future<HttpResponse<dynamic>> autoProvisionCommunity(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.studyCommunities)
  Future<HttpResponse<dynamic>> fetchCourseCommunityStats(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.generateLiveKitToken)
  Future<HttpResponse<dynamic>> generateLiveKitToken(
    @Body() Map<String, dynamic> body,
  );

  @POST('/rest/v1/study_sessions')
  Future<HttpResponse<dynamic>> recordStudySession(
    @Body() Map<String, dynamic> body,
  );

  @POST('/rest/v1/content_reports')
  Future<HttpResponse<dynamic>> reportContent(
    @Body() Map<String, dynamic> body, {
    @Header('Prefer') String prefer = 'return=representation',
  });
}
