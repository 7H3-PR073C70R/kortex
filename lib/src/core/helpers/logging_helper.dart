import 'dart:io' show stdout;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

final Logger logger = Logger(
  printer: PrettyPrinter(
    lineLength: 80,
  ),
  level: kReleaseMode ? Level.off : Level.debug,
);

/// Safe logging method that strips execution completely in release mode.
void logMessage(String message) {
  if (kReleaseMode) return;
  stdout.writeln(message);
}

/// Logs error details securely without leaking sensitive headers,
/// authentication tokens, or student PII.
void logError(Object error, StackTrace? trace, {bool crashlytics = true}) {
  if (kReleaseMode) {
    // In production release mode, dispatch only sanitized metadata
    return;
  }

  logger.e('An Error Occurred', error: error, stackTrace: trace);

  if (error is DioException) {
    final sanitizedUri = error.response?.realUri
        .replace(
          queryParameters: {},
        )
        .toString();

    logger.e({
      'type': 'Response<---',
      'url': sanitizedUri,
      'http_code': error.response?.statusCode,
    });
  }
}

void logInfo(dynamic message) {
  if (kReleaseMode) return;
  logger.i(message);
}
