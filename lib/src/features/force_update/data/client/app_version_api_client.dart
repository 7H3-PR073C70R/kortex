import 'package:dio/dio.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:retrofit/retrofit.dart';

part 'app_version_api_client.g.dart';

@RestApi()
abstract class AppVersionApiClient {
  factory AppVersionApiClient(Dio dio, {String baseUrl}) =
      _AppVersionApiClient;

  /// Fetches the version row for the given platform slug
  /// ("ios" | "android" | "macos" | "windows" | "linux").
  ///
  /// Supabase REST convention: `eq.` filter via query params, `limit=1`.
  @GET(AppApiEndpoint.appVersionConfig)
  Future<HttpResponse<dynamic>> fetchVersionConfig(
    @Queries() Map<String, dynamic> query,
  );
}
