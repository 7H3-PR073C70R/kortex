import 'package:dio/dio.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/features/profile/data/models/mfa_enroll_result_model.dart';
import 'package:kortex/src/features/profile/data/models/mfa_factor_model.dart';

/// Pure REST API client for Profile, Security, MFA, and Account operations.
class ProfileApiClient {
  ProfileApiClient(this._dio);

  final Dio _dio;

  Map<String, String> _headers([String? token]) => {
        'apikey': AppEnv.supabaseAnonKey,
        if (token != null && token.isNotEmpty)
          'Authorization': 'Bearer $token',
      };

  /// Updates user profile table and auth user metadata via REST API.
  Future<void> updateProfile({
    required String userId,
    required String authToken,
    String? displayName,
    String? photoUrl,
  }) async {
    final data = <String, dynamic>{
      'display_name': ?displayName,
      'photo_url': ?photoUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (userId.isNotEmpty && data.isNotEmpty) {
      await _dio.patch<dynamic>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.userProfiles}?id=eq.$userId',
        data: data,
        options: Options(headers: _headers(authToken)),
      );
    }

    final authData = <String, dynamic>{
      if (displayName != null) ...{
        'display_name': displayName,
        'full_name': displayName,
      },
      if (photoUrl != null) ...{
        'photo_url': photoUrl,
        'avatar_url': photoUrl,
      },
    };

    if (authData.isNotEmpty && authToken.isNotEmpty) {
      await _dio.put<dynamic>(
        '${AppApiEndpoint.baseUri}/auth/v1/user',
        data: {'data': authData},
        options: Options(headers: _headers(authToken)),
      );
    }
  }

  /// Updates password via Auth REST API.
  Future<void> updatePassword({
    required String newPassword,
    required String authToken,
  }) async {
    await _dio.put<dynamic>(
      '${AppApiEndpoint.baseUri}/auth/v1/user',
      data: {'password': newPassword},
      options: Options(headers: _headers(authToken)),
    );
  }

  /// Requests password recovery email via Auth REST API.
  Future<void> sendPasswordResetEmail(String email) async {
    await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}${AppApiEndpoint.resetPassword}',
      data: {'email': email.trim()},
      options: Options(headers: _headers()),
    );
  }

  /// Enrolls in MFA TOTP via Auth REST API.
  Future<MfaEnrollResultModel> enrollMfaTotp({
    required String authToken,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}/auth/v1/factors',
      data: {
        'factor_type': 'totp',
        'friendly_name': 'Kortex Authenticator',
      },
      options: Options(headers: _headers(authToken)),
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Empty response from MFA enrollment');
    }

    final totp = data['totp'] as Map<String, dynamic>?;
    return MfaEnrollResultModel(
      factorId: data['id'] as String? ?? '',
      secret: totp?['secret'] as String? ?? '',
      uri: totp?['uri'] as String?,
    );
  }

  /// Verifies a 6-digit TOTP code for an enrolled factor.
  Future<void> verifyMfaTotp({
    required String factorId,
    required String code,
    required String authToken,
  }) async {
    final challengeRes = await _dio.post<Map<String, dynamic>>(
      '${AppApiEndpoint.baseUri}/auth/v1/factors/$factorId/challenge',
      options: Options(headers: _headers(authToken)),
    );
    final challengeId = challengeRes.data?['id'] as String? ?? '';

    await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}/auth/v1/factors/$factorId/verify',
      data: {
        'challenge_id': challengeId,
        'code': code.trim(),
      },
      options: Options(headers: _headers(authToken)),
    );
  }

  /// Unenrolls a TOTP factor via Auth REST API.
  Future<void> unenrollMfaTotp({
    required String factorId,
    required String authToken,
  }) async {
    await _dio.delete<dynamic>(
      '${AppApiEndpoint.baseUri}/auth/v1/factors/$factorId',
      options: Options(headers: _headers(authToken)),
    );
  }

  /// Lists active MFA factors via Auth REST API.
  Future<List<MfaFactorModel>> listMfaFactors({
    required String authToken,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '${AppApiEndpoint.baseUri}/auth/v1/factors',
        options: Options(headers: _headers(authToken)),
      );
      final list = response.data;
      if (list == null) return const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(MfaFactorModel.fromJson)
          .toList();
    } on Object {
      return const [];
    }
  }

  /// Signs out all other sessions via Auth REST API.
  Future<void> signOutOtherSessions({
    required String authToken,
  }) async {
    await _dio.post<dynamic>(
      '${AppApiEndpoint.baseUri}/auth/v1/logout?scope=others',
      options: Options(headers: _headers(authToken)),
    );
  }

  /// Permanently deletes user profile and data records from database.
  Future<void> deleteAccount({
    required String userId,
    required String authToken,
  }) async {
    if (userId.isNotEmpty) {
      await _dio.delete<dynamic>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.userProfiles}?id=eq.$userId',
        options: Options(headers: _headers(authToken)),
      );
    }
  }
}
