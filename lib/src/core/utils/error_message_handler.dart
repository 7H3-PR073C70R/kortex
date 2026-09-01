import 'dart:io';
import 'package:dio/dio.dart';
import 'package:kortex/src/core/error/exceptions.dart';

extension ErrorHandler on Exception {
  /// Converts technical network, server, and authentication exceptions into
  /// clear, empathetic, and actionable user-facing messages.
  String? get errorMessage {
    try {
      if (this is DioException) {
        final error = this as DioException;
        return _formatDioError(error);
      } else if (this is ServerException) {
        final raw = (this as ServerException).message;
        return raw != null ? _cleanUserMessage(raw) : null;
      } else if (this is SocketException) {
        return 'Please check your internet connection and try again';
      } else {
        return null;
      }
    } on Exception catch (_) {
      return null;
    }
  }

  static String _formatDioError(DioException error) {
    // 1. Check if backend returned structured payload
    if (error.response?.data != null) {
      final data = error.response!.data;
      String? rawBackendMsg;
      if (data is Map) {
        rawBackendMsg = (data['msg'] as String?) ??
            (data['error_description'] as String?) ??
            (data['message'] as String?) ??
            (data['error'] as String?) ??
            (data['details'] as String?) ??
            (data['hint'] as String?);
      } else if (data is String && data.isNotEmpty) {
        rawBackendMsg = data;
      }

      if (rawBackendMsg != null && rawBackendMsg.trim().isNotEmpty) {
        final userFriendly = _cleanUserMessage(rawBackendMsg.trim());
        if (userFriendly.isNotEmpty) return userFriendly;
      }
    }

    // 2. Check connection errors or host lookup failures
    final underlyingMsg = error.message?.toLowerCase() ?? '';
    if (underlyingMsg.contains('failed host lookup') ||
        underlyingMsg.contains('connection refused') ||
        underlyingMsg.contains('network is unreachable') ||
        underlyingMsg.contains('socketexception') ||
        error.type == DioExceptionType.connectionError) {
      return 'Please check your internet connection and try again';
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.transformTimeout) {
      return 'Connection timed out. '
          'Please check your internet connection and try again';
    }

    // 3. Status code defaults if provided
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Invalid request details. '
              'Please check your inputs and try again';
        case 401:
          return 'Incorrect email or password. '
              'Please verify your credentials and try again';
        case 403:
          return 'Access restricted. '
              'You do not have permission for this action';
        case 404:
          return 'The requested study resource or account could not be found';
        case 409:
          return 'An account with this email already exists. '
              'Please sign in instead';
        case 422:
          return 'Some submitted details are invalid. '
              'Please check your inputs';
        case 429:
          return 'Too many requests. Please wait a moment before trying again';
        case 500:
        case 502:
        case 503:
        case 504:
          return 'Our servers are experiencing temporary hiccups. '
              'Please try again in a few moments';
      }
    }

    return error.message ?? 'something went wrong';
  }

  static String _cleanUserMessage(String raw) {
    final lower = raw.toLowerCase();

    // Database or internal technical failure patterns
    if (lower.contains('database error') ||
        lower.contains('saving new user') ||
        lower.contains('unexpected_failure') ||
        lower.contains('internal server error') ||
        lower.contains('postgres') ||
        lower.contains('pq:') ||
        lower.contains('violates foreign key') ||
        lower.contains('violates unique') ||
        lower.contains('relation ') ||
        lower.contains('syntax error')) {
      return 'Our servers are experiencing temporary hiccups. '
          'Please try again in a few moments';
    }

    // Authentication failure patterns
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_grant') ||
        lower.contains('invalid credentials')) {
      return 'Incorrect email or password. '
          'Please verify your details and try again';
    }
    if (lower.contains('already registered') ||
        lower.contains('user already exists') ||
        lower.contains('duplicate')) {
      return 'An account with this email already exists. '
          'Please sign in directly';
    }
    if (lower.contains('email rate limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('rate limit')) {
      return 'Too many requests in a short period. '
          'Please wait a couple of minutes before trying again';
    }
    if (lower.contains('password should be at least') ||
        lower.contains('password is too short')) {
      return 'Your password must be at least 8 characters long';
    }
    if (lower.contains('error sending confirmation email') ||
        lower.contains('error sending email') ||
        lower.contains('unable to send email')) {
      return 'Unable to send confirmation email. Please check your Supabase '
          'SMTP configuration or disable email confirmation in dashboard.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please check your email inbox to confirm your account '
          'before signing in';
    }
    if (lower.contains('signup is disabled') ||
        lower.contains('signups not allowed')) {
      return 'Registration is currently invite-only. '
          'Please join our waitlist for early access';
    }
    if (lower.contains('invalid email') ||
        lower.contains('unable to validate email')) {
      return 'Please enter a valid academic or personal email address';
    }
    if (lower.contains('connection refused') ||
        lower.contains('failed host lookup') ||
        lower.contains('socketexception') ||
        lower.contains('connection error')) {
      return 'Please check your internet connection and try again';
    }
    if (lower.contains('jwt expired') || lower.contains('token expired')) {
      return 'Your session has expired. Please sign in again to continue';
    }

    // Strip raw technical prefixes if present
    var sanitized = raw;
    if (sanitized.startsWith('Exception: ')) {
      sanitized = sanitized.substring(11);
    }
    if (sanitized.startsWith('DioException: ')) {
      sanitized = sanitized.substring(14);
    }

    return sanitized;
  }
}
