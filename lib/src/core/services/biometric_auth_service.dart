import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:local_auth/local_auth.dart';

abstract class BiometricAuthService {
  ValueListenable<bool> get isEnabledListenable;
  Future<bool> canAuthenticate();
  Future<bool> authenticate({String? localizedReason});
  bool isBiometricLockEnabled();
  Future<void> setBiometricLockEnabled({required bool enabled});

  /// The configurable background timeout threshold before re-arming the biometric lock.
  Duration get backgroundLockTimeout;
  Future<void> setBackgroundLockTimeout(Duration timeout);

  /// Records the timestamp when the application enters the background.
  void recordBackgroundedAt([DateTime? time]);

  /// Returns whether the elapsed background duration has exceeded the timeout threshold.
  bool shouldReArmLock({Duration? threshold, DateTime? now});

  /// Clears the recorded background timestamp.
  void clearBackgroundedAt();

  /// Gets the last recorded background timestamp.
  DateTime? get lastBackgroundedAt;
}

class BiometricAuthServiceImpl implements BiometricAuthService {
  BiometricAuthServiceImpl(
    this._localStorageService, {
    LocalAuthentication? auth,
  }) : _auth = auth ?? LocalAuthentication();

  final LocalStorageService _localStorageService;
  final LocalAuthentication _auth;
  late final ValueNotifier<bool> _enabledNotifier = ValueNotifier<bool>(
    _readInitialEnabled(),
  );
  bool _isPrompting = false;

  static const _biometricKey = '__biometric_lock_enabled';
  static const _timeoutKey = '__biometric_lock_timeout_seconds';
  static const Duration defaultTimeout = Duration(seconds: 30);

  DateTime? _lastBackgroundedAt;

  bool _readInitialEnabled() {
    try {
      return _localStorageService.getPreference(key: _biometricKey) == 'true';
    } on Object {
      return false;
    }
  }

  @override
  ValueListenable<bool> get isEnabledListenable => _enabledNotifier;

  @override
  Duration get backgroundLockTimeout {
    try {
      final str = _localStorageService.getPreference(key: _timeoutKey);
      if (str != null) {
        final seconds = int.tryParse(str);
        if (seconds != null && seconds >= 0) {
          return Duration(seconds: seconds);
        }
      }
    } on Object catch (_) {}
    return defaultTimeout;
  }

  @override
  Future<void> setBackgroundLockTimeout(Duration timeout) async {
    try {
      await _localStorageService.savePreference(
        key: _timeoutKey,
        data: timeout.inSeconds.toString(),
      );
    } on Object catch (_) {}
  }

  @override
  DateTime? get lastBackgroundedAt => _lastBackgroundedAt;

  @override
  void recordBackgroundedAt([DateTime? time]) {
    _lastBackgroundedAt = time ?? DateTime.now();
  }

  @override
  bool shouldReArmLock({Duration? threshold, DateTime? now}) {
    if (!isBiometricLockEnabled()) return false;
    final bgTime = _lastBackgroundedAt;
    if (bgTime == null) return false;
    final effectiveTimeout = threshold ?? backgroundLockTimeout;
    final currentTime = now ?? DateTime.now();
    return currentTime.difference(bgTime) >= effectiveTimeout;
  }

  @override
  void clearBackgroundedAt() {
    _lastBackgroundedAt = null;
  }

  @override
  Future<bool> canAuthenticate() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate({String? localizedReason}) async {
    if (_isPrompting) return false;
    _isPrompting = true;
    try {
      return await _auth.authenticate(
        localizedReason:
            localizedReason ??
            'Unlock Kortexify to access your study notes and flashcards',
      );
    } on Object catch (_) {
      return false;
    } finally {
      _isPrompting = false;
    }
  }

  @override
  bool isBiometricLockEnabled() {
    try {
      return _localStorageService.getPreference(key: _biometricKey) == 'true';
    } on Object catch (_) {
      return false;
    }
  }

  @override
  Future<void> setBiometricLockEnabled({required bool enabled}) async {
    try {
      await _localStorageService.savePreference(
        key: _biometricKey,
        data: enabled.toString(),
      );
      _enabledNotifier.value = enabled;
    } on Object catch (_) {}
  }
}
