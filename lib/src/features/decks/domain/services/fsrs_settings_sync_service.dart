import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:kortex/src/core/networking/api/app_api_endpoint.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/decks/domain/models/fsrs_user_settings.dart';

/// Persists [FsrsUserSettings] both locally (via [LocalStorageService]) and
/// remotely (via the `upsert_notification_preferences` Supabase RPC) so that
/// the pg_cron notification scheduler uses the correct reminder time and
/// timezone for each user.
///
/// Designed to be called after the user saves their settings in the Settings UI.
class FsrsSettingsSyncService {
  const FsrsSettingsSyncService();

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Saves [settings] locally and, if [syncRemote] is true and a [Dio]
  /// instance is registered in the service locator, syncs to Supabase.
  ///
  /// Returns `true` if the remote sync succeeded (or was skipped when
  /// [syncRemote] is false). Returns `false` on remote failure — the local
  /// save always succeeds.
  Future<bool> save(FsrsUserSettings settings, {bool syncRemote = true}) async {
    // 1. Persist locally.
    await _saveLocally(settings);

    if (!syncRemote) return true;

    // 2. Sync to Supabase.
    return _syncToSupabase(settings);
  }

  /// Loads [FsrsUserSettings] from [LocalStorageService].
  /// Returns the default (90%, 19:00) if nothing is persisted yet.
  FsrsUserSettings load() {
    try {
      final storage = _storage;
      if (storage == null) return const FsrsUserSettings();
      final raw = storage.getPreference(key: FsrsUserSettings.storageKey);
      if (raw == null || raw.isEmpty) return const FsrsUserSettings();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return FsrsUserSettings.fromJson(decoded);
      }
    } on Object catch (e) {
      developer.log('FsrsSettingsSyncService.load error: $e');
    }
    return const FsrsUserSettings();
  }

  /// Restores user notification preferences and desired retention from Supabase
  /// if local storage is missing or default.
  Future<FsrsUserSettings?> restoreFromRemote() async {
    try {
      final dio = _effectiveDio;
      if (dio == null) return null;

      final response = await dio.get<dynamic>(
        '${AppApiEndpoint.baseUri}${AppApiEndpoint.userProfiles}?select=*&limit=1',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List<dynamic>;
        if (list.isNotEmpty && list.first is Map<String, dynamic>) {
          final row = list.first as Map<String, dynamic>;
          final hour = (row['notification_reminder_hour'] as num?)?.toInt();
          final minute = (row['notification_reminder_minute'] as num?)?.toInt();
          final retention = (row['fsrs_desired_retention'] as num?)?.toDouble() ??
              (row['retention_benchmark'] as num?)?.toDouble();
          final dailyTarget = (row['daily_card_target'] as num?)?.toInt();

          if (hour != null || retention != null || dailyTarget != null) {
            final current = load();
            final restored = current.copyWith(
              preferredReminderHour: hour ?? current.preferredReminderHour,
              preferredReminderMinute: minute ?? current.preferredReminderMinute,
              desiredRetention: retention ?? current.desiredRetention,
              newCardsPerDay: dailyTarget ?? current.newCardsPerDay,
            );
            await _saveLocally(restored);
            return restored;
          }
        }
      }
    } on Object catch (e) {
      developer.log('FsrsSettingsSyncService.restoreFromRemote error: $e');
    }
    return null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  LocalStorageService? get _storage {
    try {
      if (locator.isRegistered<LocalStorageService>()) {
        return locator<LocalStorageService>();
      }
    } on Object catch (_) {}
    return null;
  }

  Future<void> _saveLocally(FsrsUserSettings settings) async {
    try {
      await _storage?.savePreference(
        key: FsrsUserSettings.storageKey,
        data: jsonEncode(settings.toJson()),
      );
    } on Object catch (e) {
      developer.log('FsrsSettingsSyncService: local save failed: $e');
    }
  }

  Future<bool> _syncToSupabase(FsrsUserSettings settings) async {
    try {
      final dio = _effectiveDio;
      if (dio == null) {
        developer.log(
          'FsrsSettingsSyncService: no Dio registered — skipping remote sync',
        );
        return false;
      }

      final deviceTz = await _deviceTimezone();

      final response = await dio.post<dynamic>(
        '${AppApiEndpoint.baseUri}'
        '${AppApiEndpoint.upsertNotificationPreferencesRpc}',
        data: {
          'p_reminder_hour': settings.preferredReminderHour,
          'p_reminder_minute': settings.preferredReminderMinute,
          'p_user_timezone': deviceTz,
          'p_desired_retention': settings.clampedRetention,
          'p_pace_preset': settings.pacePreset.name,
          'p_new_cards_per_day': settings.newCardsPerDay,
          'p_max_reviews_per_day': settings.maxReviewsPerDay,
          'p_is_soft_catch_up': settings.isSoftCatchUpEnabled,
          'p_reminders_enabled': settings.remindersEnabled,
        },
      );

      final ok = response.statusCode == 200 || response.statusCode == 204;
      developer.log(
        'FsrsSettingsSyncService: remote sync ${ok ? "OK" : "failed"} '
        '(HTTP ${response.statusCode})',
      );
      return ok;
    } on Object catch (e) {
      developer.log('FsrsSettingsSyncService: remote sync error: $e');
      return false;
    }
  }

  Future<String> _deviceTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } on Object catch (_) {
      return 'UTC';
    }
  }

  Dio? get _effectiveDio {
    try {
      if (locator.isRegistered<Dio>()) return locator<Dio>();
    } on Object catch (_) {}
    return null;
  }
}
