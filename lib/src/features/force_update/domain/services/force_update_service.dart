import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kortex/src/features/force_update/domain/use_cases/check_force_update_use_case.dart';

/// Orchestrates app-launch and app-resume version checks.
///
/// Any component can listen to [onForceUpdateRequired] and react when the
/// installed version is no longer accepted.  The gate is debounced to avoid
/// repeated triggers on rapid app resumes.
class ForceUpdateService {
  ForceUpdateService({required CheckForceUpdateUseCase checkForceUpdateUseCase})
      : _checkForceUpdate = checkForceUpdateUseCase;

  final CheckForceUpdateUseCase _checkForceUpdate;

  final StreamController<VersionForceRequired> _controller =
      StreamController<VersionForceRequired>.broadcast();

  Stream<VersionForceRequired> get onForceUpdateRequired => _controller.stream;

  DateTime? _lastCheckTime;
  static const Duration _minCheckInterval = Duration(minutes: 30);

  bool _isGateActive = false;

  /// True once the gate has been activated for this session.
  bool get isGateActive => _isGateActive;

  /// Runs the version check.  Safe to call on every app resume —
  /// results are debounced and duplicates suppressed.
  Future<void> check() async {
    final now = DateTime.now();
    if (_lastCheckTime != null &&
        now.difference(_lastCheckTime!) < _minCheckInterval &&
        _isGateActive) {
      return; // Already gated; no need to re-check within the window.
    }
    _lastCheckTime = now;

    try {
      final result = await _checkForceUpdate();
      if (result is VersionForceRequired && !_controller.isClosed) {
        _isGateActive = true;
        _controller.add(result);
      }
    } on Object catch (e) {
      // Network failures must never lock the user out.
      debugPrint('[ForceUpdateService] Version check failed (ignored): $e');
    }
  }

  void dispose() {
    unawaited(_controller.close());
  }
}
