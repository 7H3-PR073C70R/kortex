import 'package:flutter/material.dart';

/// User-configurable FSRS-6 scheduling preferences.
///
/// Persisted via `LocalStorageService` under key [storageKey].
/// Defaults are applied until the user explicitly configures them.
class FsrsUserSettings {
  const FsrsUserSettings({
    this.desiredRetention = defaultDesiredRetention,
    this.preferredReminderHour = defaultReminderHour,
    this.preferredReminderMinute = defaultReminderMinute,
  });

  factory FsrsUserSettings.fromJson(Map<String, dynamic> json) {
    return FsrsUserSettings(
      desiredRetention:
          (json['desiredRetention'] as num?)?.toDouble() ??
          defaultDesiredRetention,
      preferredReminderHour:
          (json['preferredReminderHour'] as int?) ?? defaultReminderHour,
      preferredReminderMinute:
          (json['preferredReminderMinute'] as int?) ?? defaultReminderMinute,
    );
  }

  // ── Storage ────────────────────────────────────────────────────────────────

  static const String storageKey = 'fsrs_user_settings';

  // ── Defaults ───────────────────────────────────────────────────────────────

  /// Default desired retention (90%) — aligns with FSRS-6 recommended baseline.
  static const double defaultDesiredRetention = 0.90;

  /// Default daily reminder time: 19:00 local.
  static const int defaultReminderHour = 19;
  static const int defaultReminderMinute = 0;

  // ── Fields ─────────────────────────────────────────────────────────────────

  /// Target probability of recall at the scheduled review date.
  /// Range: [0.80, 0.97]. Configurable via slider in Settings.
  /// A higher value produces shorter, more frequent review intervals.
  final double desiredRetention;

  /// Hour of the user's preferred daily reminder time (local timezone, 0–23).
  final int preferredReminderHour;

  /// Minute of the user's preferred daily reminder time (0–59).
  final int preferredReminderMinute;

  // ── Helpers ────────────────────────────────────────────────────────────────

  TimeOfDay get preferredReminderTime =>
      TimeOfDay(hour: preferredReminderHour, minute: preferredReminderMinute);

  /// Clamps the retention to the valid FSRS range [0.80, 0.97].
  double get clampedRetention => desiredRetention.clamp(0.80, 0.97);

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'desiredRetention': desiredRetention,
    'preferredReminderHour': preferredReminderHour,
    'preferredReminderMinute': preferredReminderMinute,
  };

  FsrsUserSettings copyWith({
    double? desiredRetention,
    int? preferredReminderHour,
    int? preferredReminderMinute,
  }) {
    return FsrsUserSettings(
      desiredRetention: desiredRetention ?? this.desiredRetention,
      preferredReminderHour:
          preferredReminderHour ?? this.preferredReminderHour,
      preferredReminderMinute:
          preferredReminderMinute ?? this.preferredReminderMinute,
    );
  }

  @override
  String toString() =>
      'FsrsUserSettings(retention=${(desiredRetention * 100).toStringAsFixed(0)}%, '
      'reminder=${preferredReminderHour.toString().padLeft(2, '0')}:'
      '${preferredReminderMinute.toString().padLeft(2, '0')})';
}
