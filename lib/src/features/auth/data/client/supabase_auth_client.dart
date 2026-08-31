import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/auth/data/models/auth_request_model.dart';
import 'package:kortex/src/features/auth/data/models/user_model.dart';

class SupabaseAuthClient {
  SupabaseAuthClient(this._dio);

  final Dio _dio;

  Map<String, String> _headers([String? token]) => {
        'apikey': AppEnv.supabaseAnonKey,
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  /// Login with email & password.
  Future<UserModel> login(LoginRequestModel body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.login}',
      data: body.toJson(),
      options: Options(headers: _headers()),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Empty response from login endpoint');
    }
    return UserModel.fromJson(data);
  }

  /// Register with email & password.
  Future<UserModel> register(RegisterRequestModel body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.register}',
      data: body.toJson(),
      options: Options(headers: _headers()),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Empty response from registration endpoint');
    }
    return UserModel.fromJson(data);
  }

  /// Authenticate with OAuth Provider.
  Future<UserModel> loginWithSocial(SocialAuthRequestModel body) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.socialAuth}',
      data: body.toJson(),
      options: Options(headers: _headers()),
    );
    final data = response.data;
    if (data == null) {
      throw Exception('Empty response from social auth endpoint');
    }
    return UserModel.fromJson(data);
  }

  /// Request password recovery email.
  Future<void> resetPassword(ResetPasswordRequestModel body) async {
    await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.resetPassword}',
      data: body.toJson(),
      options: Options(headers: _headers()),
    );
  }

  /// Sends passwordless magic link to email.
  Future<void> sendMagicLink({required String email}) async {
    await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.magicLink}',
      data: {
        'email': email,
        'create_user': true,
      },
      options: Options(headers: _headers()),
    );
  }

  /// Fetches current user profile from `profiles` table.
  Future<Map<String, dynamic>> fetchUserProfile({
    required String authToken,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.userProfiles}',
      queryParameters: {
        'select': '*',
        'limit': 1,
      },
      options: Options(headers: _headers(authToken)),
    );
    final list = response.data;
    if (list == null || list.isEmpty) {
      return {};
    }
    return list.first as Map<String, dynamic>;
  }

  /// Updates user profile track and daily card targets via Supabase RPC.
  Future<Map<String, dynamic>> updateUserProfileTrackAndGoal({
    required String track,
    required int dailyTarget,
    required String authToken,
    double retentionBenchmark = 0.85,
    bool isOnboarded = true,
  }) async {
    final response = await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.updateProfileRpc}',
      data: {
        'p_target_track': track,
        'p_daily_card_target': dailyTarget,
        'p_retention_benchmark': retentionBenchmark,
        'p_is_onboarded': isOnboarded,
      },
      options: Options(headers: _headers(authToken)),
    );
    return (response.data as Map<String, dynamic>?) ?? {};
  }

  /// Fetches standard course tracks metadata.
  Future<List<Map<String, dynamic>>> fetchCourseTracks() async {
    final response = await _dio.get<List<dynamic>>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.courseTracks}',
      queryParameters: {
        'select': '*',
      },
      options: Options(headers: _headers()),
    );
    return (response.data ?? []).cast<Map<String, dynamic>>();
  }
}
