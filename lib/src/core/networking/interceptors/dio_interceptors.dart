import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:logger/logger.dart';

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.logger});

  final Logger? logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger?.i(
      'REQUEST[${options.method}] => URL: ${options.uri}\n'
      'REQUEST DATA => ${options.data}\n'
      'Headers: ${options.headers}',
    );

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    logger?.i(
      'RESPONSE[${response.statusCode}] =>'
      ' PATH:${response.requestOptions.path}\n'
      'RESPONSE DATA: ${response.data}',
    );
    super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    logger?.e(
      'ERROR[${err.requestOptions.uri}]\n'
      'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}\n'
      'ERROR[${err.response?.data}]',
    );
    super.onError(err, handler);
  }
}

class TokenInterceptor extends QueuedInterceptor {
  TokenInterceptor({
    required this.storageService,
    required this.sessionExpiredService,
    Dio? refreshDio,
  }) : _refreshDio = refreshDio ?? Dio();

  final UserStorageService storageService;
  final SessionExpiredService sessionExpiredService;
  final Dio _refreshDio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final userToken = storageService.getToken();
    final anonKey = AppEnv.apiKey;

    if (anonKey.isNotEmpty) {
      options.headers['apikey'] = anonKey;
    }

    if (userToken != null && userToken.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $userToken';
    } else if (anonKey.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $anonKey';
    }

    super.onRequest(options, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (_isJwtExpired(err)) {
      final path = err.requestOptions.path;
      final isAuthEndpoint = path.contains('/auth/v1/token') ||
          path.contains('/auth/v1/signup') ||
          path.contains('/auth/v1/recover');

      if (!isAuthEndpoint) {
        final refreshToken = storageService.getRefreshToken();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          try {
            debugPrint(
              '[TokenInterceptor] JWT expired. Attempting token refresh...',
            );
            final refreshResponse =
                await _refreshDio.post<Map<String, dynamic>>(
              '${AppApiEndpoint.baseUri}${AppApiEndpoint.refreshToken}',
              data: {
                'refresh_token': refreshToken,
              },
              options: Options(
                headers: {
                  'apikey': AppEnv.apiKey,
                },
              ),
            );

            final data = refreshResponse.data;
            if (data != null && data.containsKey('access_token')) {
              final newAccessToken = data['access_token'] as String;
              final newRefreshToken =
                  data['refresh_token'] as String? ?? refreshToken;

              await storageService.saveAuthTokens(
                accessToken: newAccessToken,
                refreshToken: newRefreshToken,
              );

              debugPrint(
                '[TokenInterceptor] Token refresh succeeded. '
                'Retrying request...',
              );

              // Update headers and retry original request
              final options = err.requestOptions;
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              options.headers['apikey'] = AppEnv.apiKey;

              final response = await _refreshDio.fetch<dynamic>(options);
              handler.resolve(response);
              return;
            }
          } on Object catch (refreshError) {
            debugPrint(
              '[TokenInterceptor] Token refresh failed: $refreshError',
            );
          }
        }

        // Auto-logout and notify user if refresh is unavailable or failed
        debugPrint(
          '[TokenInterceptor] Auto logging out due to expired session.',
        );
        storageService.clearStorage();
        sessionExpiredService.notifySessionExpired();
      }
    }

    super.onError(err, handler);
  }

  bool _isJwtExpired(DioException err) {
    final statusCode = err.response?.statusCode;
    if (statusCode == 401) return true;

    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['code']?.toString().toUpperCase();
      final message = data['message']?.toString().toLowerCase() ?? '';
      final error = data['error']?.toString().toLowerCase() ?? '';
      final errorDesc =
          data['error_description']?.toString().toLowerCase() ?? '';

      if (code == 'PGRST303' || code == 'PGRST301' || code == 'PGRST302') {
        return true;
      }
      if (message.contains('jwt expired') ||
          message.contains('invalid jwt') ||
          message.contains('token is expired')) {
        return true;
      }
      if (error.contains('invalid_grant') || errorDesc.contains('expired')) {
        return true;
      }
    } else if (data is String) {
      final lower = data.toLowerCase();
      if (lower.contains('jwt expired') ||
          lower.contains('pgrst303') ||
          lower.contains('invalid jwt')) {
        return true;
      }
    }
    return false;
  }
}

class DataParserInterceptor extends Interceptor {
  DataParserInterceptor();

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    final dynamic data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data')) {
        response.data = data['data'];
      }
    }
    super.onResponse(response, handler);
  }
}
