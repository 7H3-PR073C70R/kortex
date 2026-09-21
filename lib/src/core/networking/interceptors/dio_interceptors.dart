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
    if (options.extra['silent'] != true) {
      logger?.i(
        'REQUEST[${options.method}] => URL: ${options.uri}\n'
        'REQUEST DATA => ${options.data}\n'
        'Headers: ${options.headers}',
      );
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (response.requestOptions.extra['silent'] != true) {
      logger?.i(
        'RESPONSE[${response.statusCode}] =>'
        ' PATH:${response.requestOptions.path}\n'
        'RESPONSE DATA: ${response.data}',
      );
    }
    super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.requestOptions.extra['silent'] == true) {
      logger?.d(
        'SILENT_HANDLED_ERROR[${err.requestOptions.uri}]\n'
        'STATUS[${err.response?.statusCode}] => ${err.response?.data}',
      );
    } else {
      logger?.e(
        'ERROR[${err.requestOptions.uri}]\n'
        'ERROR[${err.response?.statusCode}] => PATH: ${err.requestOptions.path}\n'
        'ERROR[${err.response?.data}]',
      );
    }
    super.onError(err, handler);
  }
}

class TokenInterceptor extends QueuedInterceptor {
  TokenInterceptor({
    required this.storageService,
    required this.sessionExpiredService,
    Dio? refreshDio,
  }) : _refreshDio =
           refreshDio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 15),
               sendTimeout: const Duration(seconds: 15),
             ),
           );

  final UserStorageService storageService;
  final SessionExpiredService sessionExpiredService;
  final Dio _refreshDio;

  Completer<bool>? _refreshCompleter;

  Future<bool> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final rawRefreshToken = storageService.getRefreshToken();
      final refreshToken = rawRefreshToken?.trim();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }

      debugPrint(
        '[TokenInterceptor] Refreshing JWT access token with Supabase gateway...',
      );

      final response = await _refreshDio.post<Map<String, dynamic>>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.refreshToken}',
        data: <String, dynamic>{
          'refresh_token': refreshToken,
        },
        options: Options(
          headers: <String, dynamic>{
            'apikey': AppEnv.apiKey.trim(),
            'Authorization': 'Bearer ${AppEnv.apiKey.trim()}',
            'Content-Type': 'application/json',
          },
        ),
      );

      final data = response.data;
      if (data != null && data.containsKey('access_token')) {
        final newAccessToken = data['access_token'] as String;
        final newRefreshToken =
            data['refresh_token'] as String? ?? refreshToken;

        await storageService.saveAuthTokens(
          accessToken: newAccessToken,
          refreshToken: newRefreshToken,
        );

        debugPrint(
          '[TokenInterceptor] Token refresh successfully completed.',
        );
        completer.complete(true);
        return true;
      } else {
        completer.complete(false);
        return false;
      }
    } on Object catch (e) {
      debugPrint('[TokenInterceptor] Token refresh failed: $e');
      completer.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final path = options.path;
    final isAuthEndpoint =
        path.contains('/auth/v1/token') ||
        path.contains('/auth/v1/signup') ||
        path.contains('/auth/v1/recover') ||
        path.contains('/auth/v1/verify') ||
        path.contains('/auth/v1/magiclink');

    if (!isAuthEndpoint) {
      // Pre-emptive check: If token is expired and refresh token is available, refresh it before dispatch
      if (storageService.isTokenExpired()) {
        final refreshToken = storageService.getRefreshToken();
        if (refreshToken != null && refreshToken.trim().isNotEmpty) {
          debugPrint(
            '[TokenInterceptor] Token is expired before request to $path. Pre-emptively refreshing...',
          );
          await _refreshAccessToken();
        }
      }
    }

    final rawUserToken = storageService.getToken();
    final userToken =
        rawUserToken != null &&
            rawUserToken.isNotEmpty &&
            !rawUserToken.contains(' ') &&
            !rawUserToken.contains('\n')
        ? rawUserToken.trim()
        : null;
    final anonKey = AppEnv.apiKey.trim();

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
      final isAuthEndpoint =
          path.contains('/auth/v1/token') ||
          path.contains('/auth/v1/signup') ||
          path.contains('/auth/v1/recover') ||
          path.contains('/auth/v1/verify') ||
          path.contains('/auth/v1/magiclink');

      if (!isAuthEndpoint) {
        final refreshToken = storageService.getRefreshToken();
        if (refreshToken != null && refreshToken.trim().isNotEmpty) {
          debugPrint(
            '[TokenInterceptor] Caught auth/token error on $path. Attempting token refresh...',
          );
          final refreshed = await _refreshAccessToken();
          if (refreshed) {
            final latestToken = storageService.getToken();
            final options = err.requestOptions;
            if (latestToken != null && latestToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $latestToken';
            }
            options.headers['apikey'] = AppEnv.apiKey.trim();

            try {
              final response = await _refreshDio.fetch<dynamic>(options);
              handler.resolve(response);
              return;
            } on DioException catch (retryErr) {
              debugPrint(
                '[TokenInterceptor] Retrying request after refresh threw: $retryErr',
              );
              handler.reject(retryErr);
              return;
            }
          }
        }

        // Auto-logout and notify user only if refresh is completely unavailable or failed
        debugPrint(
          '[TokenInterceptor] Auto logging out due to expired/unauthenticated session.',
        );
        storageService.clearStorage();
        sessionExpiredService.notifySessionExpired();
      }
    }

    super.onError(err, handler);
  }

  bool _isJwtExpired(DioException err) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    // Check if error is an RLS policy violation or permission error (NOT an expired token)
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final code = map['code']?.toString().toUpperCase() ?? '';
      final message = map['message']?.toString().toLowerCase() ?? '';
      if (code == '42501' ||
          code == 'ACCESSDENIED' ||
          message.contains('row-level security') ||
          message.contains('violates row-level')) {
        return false;
      }
    } else if (data is String) {
      final lower = data.toLowerCase();
      if (lower.contains('row-level security') ||
          lower.contains('violates row-level') ||
          lower.contains('42501')) {
        return false;
      }
    }

    if (statusCode == 401) return true;

    if (statusCode == 400 || statusCode == 403 || statusCode == 494) {
      if (data is String) {
        final lower = data.toLowerCase();
        if (lower.contains('not authenticated') ||
            lower.contains('unauthorized') ||
            lower.contains('request header or cookie too large') ||
            lower.contains('header too large') ||
            lower.contains('cloudflare') ||
            lower.contains('p0001') ||
            lower.contains('pgrst301') ||
            lower.contains('pgrst302') ||
            lower.contains('pgrst303') ||
            lower.contains('invalid jwt') ||
            lower.contains('jwt expired') ||
            lower.contains('token is expired')) {
          return true;
        }
      } else if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final code = map['code']?.toString().toUpperCase() ?? '';
        final message = map['message']?.toString().toLowerCase() ?? '';
        final error = map['error']?.toString().toLowerCase() ?? '';
        final errorDesc =
            map['error_description']?.toString().toLowerCase() ?? '';

        if (code == 'P0001' ||
            code == 'PGRST303' ||
            code == 'PGRST301' ||
            code == 'PGRST302' ||
            code == '401' ||
            code == 'UNAUTHORIZED') {
          return true;
        }
        if (message.contains('not authenticated') ||
            message.contains('unauthorized') ||
            message.contains('jwt expired') ||
            message.contains('invalid jwt') ||
            message.contains('token is expired') ||
            message.contains('header too large')) {
          return true;
        }
        if (error.contains('invalid_grant') ||
            error.contains('unauthorized') ||
            error.contains('not authenticated') ||
            errorDesc.contains('expired') ||
            errorDesc.contains('invalid') ||
            errorDesc.contains('revoked')) {
          return true;
        }
      }
    }

    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final code = map['code']?.toString().toUpperCase() ?? '';
      final message = map['message']?.toString().toLowerCase() ?? '';
      final error = map['error']?.toString().toLowerCase() ?? '';
      final errorDesc =
          map['error_description']?.toString().toLowerCase() ?? '';

      if (code == 'P0001' ||
          code == 'PGRST303' ||
          code == 'PGRST301' ||
          code == 'PGRST302' ||
          code == '401' ||
          code == 'UNAUTHORIZED') {
        return true;
      }
      if (message.contains('not authenticated') ||
          message.contains('unauthorized') ||
          message.contains('jwt expired') ||
          message.contains('invalid jwt') ||
          message.contains('token is expired')) {
        return true;
      }
      if (error.contains('invalid_grant') ||
          error.contains('unauthorized') ||
          error.contains('not authenticated') ||
          errorDesc.contains('expired') ||
          errorDesc.contains('invalid') ||
          errorDesc.contains('revoked')) {
        return true;
      }
    } else if (data is String) {
      final lower = data.toLowerCase();
      if (lower.contains('not authenticated') ||
          lower.contains('unauthorized') ||
          lower.contains('p0001') ||
          lower.contains('jwt expired') ||
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

class ExponentialBackoffRetryInterceptor extends Interceptor {
  ExponentialBackoffRetryInterceptor({
    Dio? dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final int maxRetries;
  final Duration initialDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final extra = err.requestOptions.extra;
    final retryCount = (extra['retry_count'] as int?) ?? 0;

    final statusCode = err.response?.statusCode;
    final isTransient =
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (statusCode != null &&
            (statusCode == 500 ||
                statusCode == 502 ||
                statusCode == 503 ||
                statusCode == 504));

    if (isTransient && retryCount < maxRetries) {
      final nextRetry = retryCount + 1;
      final multiplier = 1 << retryCount; // 1, 2, 4
      final baseDelayMs = initialDelay.inMilliseconds * multiplier;
      final jitterMs =
          (baseDelayMs * 0.2 * (DateTime.now().millisecond / 1000.0)).toInt();
      final delay = Duration(milliseconds: baseDelayMs + jitterMs);

      await Future<void>.delayed(delay);

      final newOptions = err.requestOptions;
      newOptions.extra['retry_count'] = nextRetry;

      try {
        final response = await _dio.fetch<dynamic>(newOptions);
        handler.resolve(response);
        return;
      } on DioException catch (retryErr) {
        return super.onError(retryErr, handler);
      }
    }

    super.onError(err, handler);
  }
}
