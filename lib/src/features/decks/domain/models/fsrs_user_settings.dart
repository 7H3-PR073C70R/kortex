import 'package:flutter/material.dart';

/// Pre-configured study pace profiles for deck scheduling.
enum DeckPacePreset {
  relaxed('Relaxed', '80% target retention • Light daily workload', 0.80, 10, 50),
  balanced('Balanced', '90% target retention • Optimal recall efficiency', 0.90, 20, 100),
  intensive('Intensive', '95% target retention • Fast-track exam prep', 0.95, 40, 200),
  custom('Custom FSRS-6', 'Fine-tuned parameters & custom review bounds', 0.90, 20, 100);

  const DeckPacePreset(
    this.displayName,
    this.description,
    this.targetRetention,
    this.defaultNewCards,
    this.defaultMaxReviews,
  );

  final String displayName;
  final String description;
  final double targetRetention;
  final int defaultNewCards;
  final int defaultMaxReviews;

  static DeckPacePreset fromName(String? name) {
    return DeckPacePreset.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DeckPacePreset.balanced,
    );
  }
}

/// User-configurable FSRS-6 scheduling preferences and deck pace settings.
///
/// Persisted via `LocalStorageService` under key [storageKey].
/// Defaults are applied until the user explicitly configures them.
class FsrsUserSettings {
  const FsrsUserSettings({
    this.pacePreset = DeckPacePreset.balanced,
    this.desiredRetention = defaultDesiredRetention,
    this.preferredReminderHour = defaultReminderHour,
    this.preferredReminderMinute = defaultReminderMinute,
    this.newCardsPerDay = defaultNewCardsPerDay,
    this.maxReviewsPerDay = defaultMaxReviewsPerDay,
    this.isSoftCatchUpEnabled = true,
    this.remindersEnabled = true,
  });

  factory FsrsUserSettings.fromJson(Map<String, dynamic> json) {
    final preset = DeckPacePreset.fromName(json['pacePreset'] as String?);
    final retention = (json['desiredRetention'] as num?)?.toDouble() ??
        preset.targetRetention;
    final hour = (json['preferredReminderHour'] as int?) ?? defaultReminderHour;
    final minute = (json['preferredReminderMinute'] as int?) ?? defaultReminderMinute;
    final newCards = (json['newCardsPerDay'] as int?) ?? preset.defaultNewCards;
    final maxReviews = (json['maxReviewsPerDay'] as int?) ?? preset.defaultMaxReviews;
    final softCatchUp = (json['isSoftCatchUpEnabled'] as bool?) ?? true;
    final reminderOn = (json['remindersEnabled'] as bool?) ?? true;

    return FsrsUserSettings(
      pacePreset: preset,
      desiredRetention: retention.clamp(0.80, 0.97),
      preferredReminderHour: hour.clamp(0, 23),
      preferredReminderMinute: minute.clamp(0, 59),
      newCardsPerDay: newCards.clamp(5, 100),
      maxReviewsPerDay: maxReviews.clamp(10, 500),
      isSoftCatchUpEnabled: softCatchUp,
      remindersEnabled: reminderOn,
    );
  }

  // ── Storage ────────────────────────────────────────────────────────────────

  static const String storageKey = 'fsrs_user_settings';

  // ── Defaults ───────────────────────────────────────────────────────────────

  static const double defaultDesiredRetention = 0.90;
  static const int defaultReminderHour = 19;
  static const int defaultReminderMinute = 0;
  static const int defaultNewCardsPerDay = 20;
  static const int defaultMaxReviewsPerDay = 100;

  // ── Fields ─────────────────────────────────────────────────────────────────

  final DeckPacePreset pacePreset;

  /// Target probability of recall at the scheduled review date.
  /// Range: [0.80, 0.97].
  final double desiredRetention;

  /// Hour of the user's preferred daily reminder time (local timezone, 0–23).
  final int preferredReminderHour;

  /// Minute of the user's preferred daily reminder time (0–59).
  final int preferredReminderMinute;

  /// Maximum new flashcards introduced daily per deck. Range: [5, 100].
  final int newCardsPerDay;

  /// Maximum review flashcards allowed daily per deck. Range: [10, 500].
  final int maxReviewsPerDay;

  /// Whether soft catch-up queue prioritization is enabled to prevent backlogs.
  final bool isSoftCatchUpEnabled;

  /// Whether daily study reminder notifications are enabled.
  final bool remindersEnabled;

  // ── Helpers ────────────────────────────────────────────────────────────────

  TimeOfDay get preferredReminderTime =>
      TimeOfDay(hour: preferredReminderHour, minute: preferredReminderMinute);

  /// Clamps the retention to the valid FSRS range [0.80, 0.97].
  double get clampedRetention => desiredRetention.clamp(0.80, 0.97);

  // ── Serialisation ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'pacePreset': pacePreset.name,
    'desiredRetention': clampedRetention,
    'preferredReminderHour': preferredReminderHour.clamp(0, 23),
    'preferredReminderMinute': preferredReminderMinute.clamp(0, 59),
    'newCardsPerDay': newCardsPerDay.clamp(5, 100),
    'maxReviewsPerDay': maxReviewsPerDay.clamp(10, 500),
    'isSoftCatchUpEnabled': isSoftCatchUpEnabled,
    'remindersEnabled': remindersEnabled,
  };

  FsrsUserSettings copyWith({
    DeckPacePreset? pacePreset,
    double? desiredRetention,
    int? preferredReminderHour,
    int? preferredReminderMinute,
    int? newCardsPerDay,
    int? maxReviewsPerDay,
    bool? isSoftCatchUpEnabled,
    bool? remindersEnabled,
  }) {
    return FsrsUserSettings(
      pacePreset: pacePreset ?? this.pacePreset,
      desiredRetention: desiredRetention ?? this.desiredRetention,
      preferredReminderHour:
          preferredReminderHour ?? this.preferredReminderHour,
      preferredReminderMinute:
          preferredReminderMinute ?? this.preferredReminderMinute,
      newCardsPerDay: newCardsPerDay ?? this.newCardsPerDay,
      maxReviewsPerDay: maxReviewsPerDay ?? this.maxReviewsPerDay,
      isSoftCatchUpEnabled: isSoftCatchUpEnabled ?? this.isSoftCatchUpEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }

  @override
  String toString() =>
      'FsrsUserSettings(preset=${pacePreset.displayName}, '
      'retention=${(clampedRetention * 100).toStringAsFixed(0)}%, '
      'newCards=$newCardsPerDay/day, maxReviews=$maxReviewsPerDay/day, '
      'reminder=${preferredReminderHour.toString().padLeft(2, '0')}:'
      '${preferredReminderMinute.toString().padLeft(2, '0')})';
}
