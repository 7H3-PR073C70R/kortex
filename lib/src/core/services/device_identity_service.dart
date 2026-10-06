import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';

/// Centralized service for generating and retrieving persistent, unique
/// device identifiers and device metadata for backend session enforcement.
class DeviceIdentityService {
  DeviceIdentityService({
    LocalStorageService? localStorageService,
    FlutterSecureStorage? secureStorage,
  })  : _localStorage = localStorageService,
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
            );

  final LocalStorageService? _localStorage;
  final FlutterSecureStorage _secureStorage;

  static const String _deviceIdKey = 'kortex_device_id';
  String? _cachedDeviceId;

  /// Retrieves or generates a persistent, unique device UUID.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      final existing = await _secureStorage.read(key: _deviceIdKey);
      if (existing != null && existing.isNotEmpty) {
        _cachedDeviceId = existing;
        return existing;
      }
    } on Object catch (e) {
      debugPrint('[DeviceIdentityService] SecureStorage read warning: $e');
    }

    try {
      final localStorage = _localStorage;
      if (localStorage != null) {
        final prefsExisting = localStorage.getPreference(key: _deviceIdKey);
        if (prefsExisting != null && prefsExisting.isNotEmpty) {
          _cachedDeviceId = prefsExisting;
          return prefsExisting;
        }
      }
    } on Object catch (_) {}

    // Generate new persistent device UUID
    final newId = _generateUniqueDeviceId();
    _cachedDeviceId = newId;

    try {
      await _secureStorage.write(key: _deviceIdKey, value: newId);
    } on Object catch (_) {}

    try {
      final localStorage = _localStorage;
      if (localStorage != null) {
        await localStorage.savePreference(key: _deviceIdKey, data: newId);
      }
    } on Object catch (_) {}

    return newId;
  }

  /// Returns the platform identifier string: 'ios', 'android', 'web', 'macos', 'windows', 'linux'.
  String get platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'linux';
    }
  }

  /// Returns a human-readable description of this device.
  String get deviceName {
    if (kIsWeb) return 'Web Browser (${_getPlatformName()})';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iPhone / iPad';
      case TargetPlatform.android:
        return 'Android Device';
      case TargetPlatform.macOS:
        return 'Mac Desktop App';
      case TargetPlatform.windows:
        return 'Windows Desktop App';
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'Linux Desktop App';
    }
  }

  String _getPlatformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'Linux';
    }
  }

  static String _generateUniqueDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final microseconds = DateTime.now().microsecondsSinceEpoch;
    final seed = '${timestamp}_$microseconds';
    final hash = seed.hashCode.toRadixString(16).padLeft(8, '0');
    return 'dev_$hash-$timestamp';
  }
}
