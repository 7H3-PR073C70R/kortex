import 'package:flutter/foundation.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:local_auth/local_auth.dart';

abstract class BiometricAuthService {
  ValueListenable<bool> get isEnabledListenable;
  Future<bool> canAuthenticate();
  Future<bool> authenticate({String? localizedReason});
  bool isBiometricLockEnabled();
  Future<void> setBiometricLockEnabled({required bool enabled});
}

class BiometricAuthServiceImpl implements BiometricAuthService {
  BiometricAuthServiceImpl(
    this._localStorageService, {
    LocalAuthentication? auth,
  })  : _auth = auth ?? LocalAuthentication();

  final LocalStorageService _localStorageService;
  final LocalAuthentication _auth;
  late final ValueNotifier<bool> _enabledNotifier = ValueNotifier<bool>(
    _readInitialEnabled(),
  );
  bool _isPrompting = false;

  static const _biometricKey = '__biometric_lock_enabled';

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
        localizedReason: localizedReason ??
            'Unlock Kortex to access your study notes and flashcards',
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
