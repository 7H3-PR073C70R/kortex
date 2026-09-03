import 'dart:async';

import 'package:flutter/services.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';

/// Centralized haptic and sensory feedback controller for Kortex.
/// Respects user preferences configured in App & Sensory Settings.
class AppFeedback {
  AppFeedback._();

  static const String _hapticsKey = '__kortex_haptics_enabled__';

  static bool get isHapticsEnabled {
    try {
      final storage = locator<LocalStorageService>();
      final pref = storage.getPreference(key: _hapticsKey);
      return pref == null || pref == 'true';
    } on Object {
      return true;
    }
  }

  static Future<void> setHapticsEnabled({required bool enabled}) async {
    try {
      final storage = locator<LocalStorageService>();
      await storage.savePreference(
        key: _hapticsKey,
        data: enabled ? 'true' : 'false',
      );
    } on Object {
      return;
    }
  }

  static void light() {
    if (!isHapticsEnabled) return;
    unawaited(HapticFeedback.lightImpact());
  }

  static void medium() {
    if (!isHapticsEnabled) return;
    unawaited(HapticFeedback.mediumImpact());
  }

  static void heavy() {
    if (!isHapticsEnabled) return;
    unawaited(HapticFeedback.heavyImpact());
  }

  static void selection() {
    if (!isHapticsEnabled) return;
    unawaited(HapticFeedback.selectionClick());
  }

  static void vibrate() {
    if (!isHapticsEnabled) return;
    unawaited(HapticFeedback.vibrate());
  }
}
