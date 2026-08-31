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
  Future<UserModel> register(@Body() RegisterRequestModel body);

  @POST(AppApiEndpoint.socialAuth)
  Future<UserModel> loginWithSocial(@Body() SocialAuthRequestModel body);

  @POST(AppApiEndpoint.resetPassword)
  Future<void> resetPassword(@Body() ResetPasswordRequestModel body);
}
