import 'dart:async';
import 'package:flutter/foundation.dart';

/// Centralized service handling automatic logout and user notification
/// when JWT tokens expire (PGRST303, invalid_jwt, 401).
class SessionExpiredService {
  SessionExpiredService();

  final StreamController<String> _sessionExpiredController =
      StreamController<String>.broadcast();

  Stream<String> get onSessionExpired => _sessionExpiredController.stream;

  DateTime? _lastNotificationTime;
  static const Duration _debounceDuration = Duration(seconds: 3);

  /// Notifies listeners that user session has expired with a friendly message.
  void notifySessionExpired([
    String message = 'Your session has expired. Please sign in again.',
  ]) {
    final now = DateTime.now();
    if (_lastNotificationTime != null &&
        now.difference(_lastNotificationTime!) < _debounceDuration) {
      return;
    }
    _lastNotificationTime = now;

    debugPrint('[SessionExpiredService] Triggering session expired: $message');
    if (!_sessionExpiredController.isClosed) {
      _sessionExpiredController.add(message);
    }
  }

  void dispose() {
    unawaited(_sessionExpiredController.close());
  }
}
