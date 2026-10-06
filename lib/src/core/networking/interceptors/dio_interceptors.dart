import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/constants/app_env.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/device_identity_service.dart';
import 'package:kortex/src/core/services/session_expired_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:logger/logger.dart';

enum RefreshTokenResult {
  success,
  transientNetworkError,
  invalidSession,
}

class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({this.logger});

  final Logger? logger;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!kReleaseMode && options.extra['silent'] != true) {
      final dynamic data = options.data;
      String dataStr;
      if (data is String) {
        dataStr = data.length > 500
            ? '${data.substring(0, 500)}... [truncated ${data.length} chars]'
            : data;
      } else if (data is Map) {
        final previewMap = Map<dynamic, dynamic>.from(data);
        const sensitiveKeys = {
          'password',
          'new_password',
          'newpassword',
          'current_password',
          'currentpassword',
          'refresh_token',
          'refreshtoken',
          'token',
          'access_token',
          'accesstoken',
          'otp',
          'email',
        };
        for (final key in previewMap.keys.toList()) {
          final lower = key.toString().toLowerCase();
          if (sensitiveKeys.contains(lower)) {
            previewMap[key] = '[REDACTED]';
          }
        }
        if (previewMap.containsKey('raw_text') &&
            previewMap['raw_text'] is String) {
          final t = previewMap['raw_text'] as String;
          if (t.length > 300) {
            previewMap['raw_text'] =
                '${t.substring(0, 300)}... [truncated ${t.length} chars]';
          }
        }
        if (previewMap.containsKey('rawText') &&
            previewMap['rawText'] is String) {
          final t = previewMap['rawText'] as String;
          if (t.length > 300) {
            previewMap['rawText'] =
                '${t.substring(0, 300)}... [truncated ${t.length} chars]';
          }
        }
        dataStr = previewMap.toString();
        if (dataStr.length > 800) {
          dataStr = '${dataStr.substring(0, 800)}... [truncated]';
        }
      } else {
        dataStr = '$data';
        if (dataStr.length > 800) {
          dataStr = '${dataStr.substring(0, 800)}... [truncated]';
        }
      }

      // Redact sensitive headers before logging — never log raw tokens or keys.
      final safeHeaders = Map<String, dynamic>.from(options.headers)
        ..updateAll((key, value) {
          final lower = key.toLowerCase();
          if (lower == 'authorization' ||
              lower == 'apikey' ||
              lower == 'api-key' ||
              lower == 'cookie' ||
              lower == 'set-cookie' ||
              lower == 'x-api-key') {
            return '[REDACTED]';
          }
          return value;
        });
      logger?.i(
        'REQUEST[${options.method}] => URL: ${options.uri}\n'
        'REQUEST DATA => $dataStr\n'
        'Headers: $safeHeaders',
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
      final resStr = '${response.data}';
      final truncatedRes = resStr.length > 1000
          ? '${resStr.substring(0, 1000)}... [truncated ${resStr.length} chars]'
          : resStr;
      logger?.i(
        'RESPONSE[${response.statusCode}] =>'
        ' PATH:${response.requestOptions.path}\n'
        'RESPONSE DATA: $truncatedRes',
      );
    }
    super.onResponse(response, handler);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final responseData = err.response?.data;
    final isStorageDuplicate = err.response?.statusCode == 409 ||
        (err.response?.statusCode == 400 &&
            responseData is Map &&
            (responseData['code'] == 'KeyAlreadyExists' ||
                responseData['error'] == 'Duplicate' ||
                responseData['statusCode'] == 409 ||
                responseData['statusCode'] == '409'));

    if (err.requestOptions.extra['silent'] == true) {
      if (!isStorageDuplicate) {
        logger?.d(
          'SILENT_HANDLED_ERROR[${err.requestOptions.uri}]\n'
          'STATUS[${err.response?.statusCode}] => ${err.response?.data}',
        );
      }
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

  Completer<RefreshTokenResult>? _refreshCompleter;

  Future<RefreshTokenResult> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<RefreshTokenResult>();
    _refreshCompleter = completer;

    try {
      final rawRefreshToken = storageService.getRefreshToken();
      final refreshToken = rawRefreshToken?.trim();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(RefreshTokenResult.invalidSession);
        return RefreshTokenResult.invalidSession;
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
        completer.complete(RefreshTokenResult.success);
        return RefreshTokenResult.success;
      } else {
        completer.complete(RefreshTokenResult.invalidSession);
        return RefreshTokenResult.invalidSession;
      }
    } on DioException catch (dioErr) {
      final type = dioErr.type;
      final status = dioErr.response?.statusCode;
      final isConnectionIssue =
          type == DioExceptionType.connectionTimeout ||
          type == DioExceptionType.sendTimeout ||
          type == DioExceptionType.receiveTimeout ||
          type == DioExceptionType.connectionError ||
          dioErr.error is SocketException ||
          dioErr.message?.toLowerCase().contains('socket') == true ||
          dioErr.message?.toLowerCase().contains('network is unreachable') == true;

      final isServerError = status != null && status >= 500 && status <= 599;

      if (isConnectionIssue || isServerError) {
        debugPrint(
          '[TokenInterceptor] Token refresh encountered transient network/server error ($type / $status). Preserving session.',
        );
        completer.complete(RefreshTokenResult.transientNetworkError);
        return RefreshTokenResult.transientNetworkError;
      }

      final data = dioErr.response?.data;
      final errStr = data?.toString().toLowerCase() ?? '';
      if (status == 400 || status == 401 || status == 403) {
        if (errStr.contains('invalid_grant') ||
            errStr.contains('invalid refresh token') ||
            errStr.contains('refresh_token_not_found') ||
            errStr.contains('revoked') ||
            errStr.contains('not found')) {
          debugPrint(
            '[TokenInterceptor] Refresh token explicitly rejected by auth server: $data',
          );
          completer.complete(RefreshTokenResult.invalidSession);
          return RefreshTokenResult.invalidSession;
        }
      }

      debugPrint(
        '[TokenInterceptor] Token refresh failed with status $status: $dioErr. Treating as invalid session.',
      );
      completer.complete(RefreshTokenResult.invalidSession);
      return RefreshTokenResult.invalidSession;
    } on Object catch (e) {
      debugPrint('[TokenInterceptor] Token refresh unexpected error: $e');
      completer.complete(RefreshTokenResult.transientNetworkError);
      return RefreshTokenResult.transientNetworkError;
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

    if (locator.isRegistered<DeviceIdentityService>()) {
      try {
        final deviceIdentity = locator<DeviceIdentityService>();
        final deviceId = await deviceIdentity.getDeviceId();
        options.headers['X-Device-Id'] = deviceId;
        options.headers['X-Device-Name'] = deviceIdentity.deviceName;
        options.headers['X-Platform'] = deviceIdentity.platform;
      } on Object catch (_) {}
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
          final refreshResult = await _refreshAccessToken();
          if (refreshResult == RefreshTokenResult.success) {
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
          } else if (refreshResult == RefreshTokenResult.transientNetworkError) {
            // Transient offline/network issue: DO NOT clear storage or log out.
            debugPrint(
              '[TokenInterceptor] Refresh failed due to network/offline condition. Preserving session.',
            );
            super.onError(err, handler);
            return;
          }
        }

        // Auto-logout ONLY if refresh is definitively invalid/revoked
        debugPrint(
          '[TokenInterceptor] Auto logging out due to explicitly revoked/invalid session.',
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
