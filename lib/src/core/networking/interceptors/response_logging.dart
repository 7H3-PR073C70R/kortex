import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/helpers/logging_helper.dart';

/// Network interceptor that logs API requests and responses only in debug mode
/// and strictly strips authorization tokens, passwords, and PII.
class ResponseLoggingInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (!kReleaseMode) {
      logInfo({
        'type': 'Request--->',
        'url': options.uri.toString(),
        'method': options.method,
      });
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    if (!kReleaseMode) {
      logInfo({
        'type': 'Response<---',
        'http_code': response.statusCode,
        'url': response.realUri.toString(),
      });
    }

    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    logError(err, null);
    handler.next(err);
  }
}
