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
    try {
      unawaited(HapticFeedback.lightImpact());
    } on Object catch (_) {}
  }

  static void medium() {
    if (!isHapticsEnabled) return;
    try {
      unawaited(HapticFeedback.mediumImpact());
    } on Object catch (_) {}
  }

  static void heavy() {
    if (!isHapticsEnabled) return;
    try {
      unawaited(HapticFeedback.heavyImpact());
    } on Object catch (_) {}
  }

  static void celebration() {
    if (!isHapticsEnabled) return;
    try {
      unawaited(HapticFeedback.heavyImpact());
      Future.delayed(const Duration(milliseconds: 120), () {
        if (isHapticsEnabled) {
          try {
            unawaited(HapticFeedback.mediumImpact());
          } on Object catch (_) {}
        }
      });
    } on Object catch (_) {}
  }

  static void lifeline() {
    if (!isHapticsEnabled) return;
    try {
      unawaited(HapticFeedback.lightImpact());
      Future.delayed(const Duration(milliseconds: 80), () {
        if (isHapticsEnabled) {
          try {
            unawaited(HapticFeedback.selectionClick());
          } on Object catch (_) {}
        }
      });
    } on Object catch (_) {}
  }

  static void selection() {
    if (!isHapticsEnabled) return;
    try {
      unawaited(HapticFeedback.selectionClick());
    } on Object catch (_) {}
  }

  static void vibrate() {
    if (!isHapticsEnabled) return;
    try {
      unawaited(HapticFeedback.vibrate());
    } on Object catch (_) {}
  }
}
