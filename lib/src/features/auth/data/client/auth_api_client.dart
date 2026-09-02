import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';
import 'package:retrofit/retrofit.dart';

part 'auth_api_client.g.dart';

@RestApi()
abstract class AuthApiClient {
  factory AuthApiClient(Dio dio, {String baseUrl}) = _AuthApiClient;

  @POST(AppApiEndpoint.login)
  Future<UserModel> login(@Body() LoginRequestModel body);

  @POST(AppApiEndpoint.register)
  Future<UserModel> register(@Body() Map<String, dynamic> body);

  @POST(AppApiEndpoint.socialAuth)
  Future<UserModel> loginWithSocial(@Body() SocialAuthRequestModel body);

  @POST(AppApiEndpoint.resetPassword)
  Future<void> resetPassword(@Body() ResetPasswordRequestModel body);

  @POST(AppApiEndpoint.magicLink)
  Future<void> sendMagicLink(@Body() Map<String, dynamic> body);

  @POST(AppApiEndpoint.otpVerify)
  Future<UserModel> verifyOtp(@Body() Map<String, dynamic> body);

  @POST(AppApiEndpoint.refreshToken)
  Future<UserModel> refreshAuthToken(@Body() Map<String, dynamic> body);

  @GET(AppApiEndpoint.userProfiles)
  Future<HttpResponse<dynamic>> fetchUserProfile(
    @Queries() Map<String, dynamic> query,
  );

  @POST(AppApiEndpoint.updateProfileRpc)
  Future<HttpResponse<dynamic>> updateUserProfileTrackAndGoal(
    @Body() Map<String, dynamic> body,
  );

  @GET(AppApiEndpoint.courseTracks)
  Future<HttpResponse<dynamic>> fetchCourseTracks(
    @Queries() Map<String, dynamic> query,
  );
}
