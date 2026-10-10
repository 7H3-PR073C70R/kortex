import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/ingestion/data/data_sources/ingestion_remote_data_source.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/features/syllabot/data/data_sources/syllabot_remote_data_source.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';

enum DeckExportFormat {
  csv,
  anki,
  pdfPrintable,
  json,
}

/// Centralized service for validating Kortex Pro entitlements,
/// enforcing feature boundaries, and presenting paywall upgrades.
class SubscriptionGuard {
  SubscriptionGuard({
    UserStorageService? userStorageService,
    LocalStorageService? localStorageService,
    RevenueCatService? revenueCatService,
    IngestionRemoteDataSource? ingestionRemoteDataSource,
    SyllabotRemoteDataSource? syllabotRemoteDataSource,
  }) : _userStorage = userStorageService,
       _localStorage = localStorageService,
       _revenueCat = revenueCatService ?? RevenueCatService.instance,
       _ingestionRemoteDataSource = ingestionRemoteDataSource,
       _syllabotRemoteDataSource = syllabotRemoteDataSource;

  final UserStorageService? _userStorage;
  final LocalStorageService? _localStorage;
  final RevenueCatService _revenueCat;
  final IngestionRemoteDataSource? _ingestionRemoteDataSource;
  final SyllabotRemoteDataSource? _syllabotRemoteDataSource;

  IngestionRemoteDataSource? get _remoteDataSource =>
      _ingestionRemoteDataSource ??
      (locator.isRegistered<IngestionRemoteDataSource>()
          ? locator<IngestionRemoteDataSource>()
          : null);

  SyllabotRemoteDataSource? get _effectiveSyllabotRemoteDataSource =>
      _syllabotRemoteDataSource ??
      (locator.isRegistered<SyllabotRemoteDataSource>()
          ? locator<SyllabotRemoteDataSource>()
          : null);

  UserStorageService get _effectiveUserStorage =>
      _userStorage ??
      (locator.isRegistered<UserStorageService>()
          ? locator<UserStorageService>()
          : throw StateError('UserStorageService is not registered.'));

  LocalStorageService get _effectiveLocalStorage =>
      _localStorage ??
      (locator.isRegistered<LocalStorageService>()
          ? locator<LocalStorageService>()
          : throw StateError('LocalStorageService is not registered.'));

  /// Fast synchronous check against cached persistence.
  bool get isPro {
    try {
      if (_effectiveUserStorage.isProSubscriber()) return true;
      if (locator.isRegistered<AuthBloc>()) {
        return locator<AuthBloc>().state.isPro;
      }
    } on Object {
      return false;
    }
    return false;
  }

  /// Authoritatively refreshes Pro status with RevenueCat.
  Future<bool> isProAuthoritative() async {
    return _revenueCat.syncCustomerEntitlements();
  }

  // --- Feature Restrictions ---

  /// Cloud AI engines (Gemini/Edge Functions) are accessible to all users.
  /// Free tier users get 20 queries/day for Cloud AI, while Pro users get unlimited queries.
  /// Local on-device GGUF inference is ALWAYS free and unlimited for all users.
  bool canAccessCloudAi() => true;

  /// Free users get up to 50MB per file and 3 uploads per day.
  /// Pro users get up to 200MB per file and unlimited daily uploads.
  static const int freeMaxSizeBytes = 50 * 1024 * 1024; // 50MB
  static const int proMaxSizeBytes = 200 * 1024 * 1024; // 200MB
  static const int freeDailyUploadLimit = 3;

  bool canUploadFileSize(int fileSizeBytes) {
    if (isPro) return fileSizeBytes <= proMaxSizeBytes;
    return fileSizeBytes <= freeMaxSizeBytes;
  }

  int getTodayUploadCount() {
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final lastDate = _effectiveLocalStorage.getPreference(
        key: PrefKeys.lastUploadDate,
      );
      if (lastDate != todayStr) {
        return 0;
      }
      final countStr = _effectiveLocalStorage.getPreference(
        key: PrefKeys.dailyUploadCount,
      );
      return int.tryParse(countStr ?? '0') ?? 0;
    } on Object {
      return 0;
    }
  }

  Future<void> recordDocumentUpload() async {
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final current = getTodayUploadCount();
      await _effectiveLocalStorage.savePreference(
        key: PrefKeys.lastUploadDate,
        data: todayStr,
      );
      await _effectiveLocalStorage.savePreference(
        key: PrefKeys.dailyUploadCount,
        data: (current + 1).toString(),
      );
    } on Object catch (_) {}
  }

  bool canUploadDocument({required int fileSizeBytes}) {
    if (isPro) return fileSizeBytes <= proMaxSizeBytes;
    if (fileSizeBytes > freeMaxSizeBytes) return false;
    return getTodayUploadCount() < freeDailyUploadLimit;
  }

  /// Free users get 20 Syllabot Cloud AI queries per day (MON-04). Pro is unlimited.
  /// On-Device AI queries are unlimited for all users.
  static const int freeDailySyllabotLimit = 20;

  int _cachedTodaySyllabotCount = 0;

  /// Returns today's Syllabot query count from authoritative server tracking.
  int getTodaySyllabotQueryCount() => _cachedTodaySyllabotCount;

  /// Authoritatively queries Supabase Postgres DB / RPC for today's Syllabot quota and count.
  Future<Map<String, dynamic>> fetchSyllabotQuota() async {
    final ds = _effectiveSyllabotRemoteDataSource;
    if (ds == null) {
      return {
        'is_pro': isPro,
        'today_count': _cachedTodaySyllabotCount,
        'limit': isPro ? null : freeDailySyllabotLimit,
        'remaining': isPro
            ? null
            : (freeDailySyllabotLimit - _cachedTodaySyllabotCount)
                .clamp(0, freeDailySyllabotLimit),
        'can_use': canQuerySyllabot(),
      };
    }

    try {
      final quota = await ds.getSyllabotQuota();
      final todayCount = (quota['today_count'] as num?)?.toInt();
      if (todayCount != null) {
        _cachedTodaySyllabotCount = todayCount;
      }
      return quota;
    } on Object catch (_) {
      return {
        'is_pro': isPro,
        'today_count': _cachedTodaySyllabotCount,
        'limit': isPro ? null : freeDailySyllabotLimit,
        'remaining': isPro
            ? null
            : (freeDailySyllabotLimit - _cachedTodaySyllabotCount)
                .clamp(0, freeDailySyllabotLimit),
        'can_use': canQuerySyllabot(),
      };
    }
  }

  /// Authoritatively records a Syllabot query usage in Postgres via RPC.
  /// Does NOT use frontend local storage.
  Future<void> recordSyllabotQuery({
    ExecutionEngineType engineType = ExecutionEngineType.cloudRemote,
  }) async {
    if (engineType == ExecutionEngineType.localOnDevice) return;
    _cachedTodaySyllabotCount++;
    final ds = _effectiveSyllabotRemoteDataSource;
    if (ds != null) {
      try {
        final result = await ds.recordSyllabotUsage();
        final updatedCount = (result['today_count'] as num?)?.toInt();
        if (updatedCount != null) {
          _cachedTodaySyllabotCount = updatedCount;
        }
      } on Object catch (_) {}
    }
  }

  /// Validates whether the user can query Syllabot.
  /// On-device local engine is 100% UNLIMITED for all users.
  /// Pro is unlimited (monitored and counted server-side).
  /// Free tier is gated by the daily server quota.
  bool canQuerySyllabot({
    ExecutionEngineType engineType = ExecutionEngineType.cloudRemote,
  }) {
    if (engineType == ExecutionEngineType.localOnDevice) return true;
    if (isPro) return true;
    return _cachedTodaySyllabotCount < freeDailySyllabotLimit;
  }

  /// Offline Entitlement Grace Period (MON-05): 7-day cache validation.
  static const int offlineGracePeriodDays = 7;

  bool isOfflineEntitlementValid() {
    if (!isPro) return false;
    try {
      final cachedDateStr = _effectiveLocalStorage.getPreference(
        key: PrefKeys.proEntitlementCacheDate,
      );
      if (cachedDateStr == null || cachedDateStr.isEmpty) {
        return true;
      }
      final cachedDate = DateTime.tryParse(cachedDateStr);
      if (cachedDate == null) return true;
      final diffDays = DateTime.now().difference(cachedDate).inDays;
      return diffDays <= offlineGracePeriodDays;
    } on Object {
      return true;
    }
  }

  /// Free users get CSV. Anki and High-Density Printable PDFs require Pro.
  bool canExportDeck(DeckExportFormat format) {
    if (isPro) return true;
    return format == DeckExportFormat.csv;
  }

  /// Free tier can sync 1 LMS course. Pro is unlimited.
  bool canSyncMultipleLmsCourses(int currentCourseCount) {
    if (isPro) return true;
    return currentCourseCount < 1;
  }

  /// CBT Exam cognitive AI weakness breakdown requires Pro.
  bool canAccessAiDiagnostics() => isPro;

  /// Real-time hands-free voice dialogue with Syllabot AI requires Pro.
  bool canAccessVoiceDialogue() => isPro;

  /// Automated flashcard deck synthesis from Syllabot chat requires Pro.
  bool canConvertChatToDeck() => isPro;

  /// Audio lecture ingestion and Whisper speech-to-text synthesis requires Pro.
  bool canTranscribeAudioLecture() => isPro;

  /// Publishing study decks to the global community marketplace requires Pro.
  bool canPublishToMarketplace() => isPro;

  /// Live voice pod microphone broadcasting in study rooms requires Pro.
  /// (Listening, text chat, and collaborative whiteboard remain free).
  bool canBroadcastRoomVoice() => isPro;

  // --- Synthesis Mode Boundaries ---

  /// Fast Local Synthesis is 100% on-device and completely UNLIMITED for all users (free & Pro).
  /// There is NO CAP on Local Synthesis.
  bool canUseLocalSynthesis() => true;

  /// AI Smart Gen (cloud LLM) is a Pro-exclusive feature with a daily cap to prevent API abuse/cost overruns.
  /// Free users have 0 daily AI Smart Gen (must upgrade to Pro).
  /// Pro users have a daily quota of 30 uses per day.
  static const int proDailyAiSmartLimit = 30;

  int _cachedTodayAiSmartGenCount = 0;

  /// Returns the cached count of AI Smart Gen requests made today.
  int getTodayAiSmartGenCount() => _cachedTodayAiSmartGenCount;

  /// Returns remaining AI Smart Gen quota for today. Free users have 0.
  int getRemainingAiSmartGenCount() {
    if (!isPro) return 0;
    return (proDailyAiSmartLimit - _cachedTodayAiSmartGenCount)
        .clamp(0, proDailyAiSmartLimit);
  }

  /// Authoritatively queries Supabase Postgres DB / RPC for today's AI Smart Gen quota.
  Future<Map<String, dynamic>> fetchAiSmartGenQuota() async {
    final ds = _remoteDataSource;
    if (ds == null) {
      return {
        'is_pro': isPro,
        'today_count': _cachedTodayAiSmartGenCount,
        'limit': proDailyAiSmartLimit,
        'remaining': getRemainingAiSmartGenCount(),
        'can_use': canUseAiSmartGen(),
      };
    }

    try {
      final quota = await ds.getAiSmartGenQuota();
      final todayCount = (quota['today_count'] as num?)?.toInt();
      if (todayCount != null) {
        _cachedTodayAiSmartGenCount = todayCount;
      }
      return quota;
    } on Object catch (_) {
      return {
        'is_pro': isPro,
        'today_count': _cachedTodayAiSmartGenCount,
        'limit': proDailyAiSmartLimit,
        'remaining': getRemainingAiSmartGenCount(),
        'can_use': canUseAiSmartGen(),
      };
    }
  }

  /// Authoritatively records an AI Smart Gen synthesis usage in Postgres via RPC.
  Future<void> recordAiSmartGenUsage() async {
    _cachedTodayAiSmartGenCount++;
    final ds = _remoteDataSource;
    if (ds != null) {
      try {
        final result = await ds.recordAiSmartGenUsage();
        final updatedCount = (result['today_count'] as num?)?.toInt();
        if (updatedCount != null) {
          _cachedTodayAiSmartGenCount = updatedCount;
        }
      } on Object catch (_) {}
    }
  }

  /// Validates whether the user can execute AI Smart Gen.
  /// Returns false if not Pro or if the daily cap has been reached.
  bool canUseAiSmartGen() {
    if (!isPro) return false;
    return _cachedTodayAiSmartGenCount < proDailyAiSmartLimit;
  }

  /// Overall document synthesis validator.
  /// Fast Local synthesis is UNLIMITED (no cap) for all users within file size limits.
  /// AI Smart Gen requires Pro and is subject to the daily cap.
  bool canSynthesizeDocument({
    required int fileSizeBytes,
    required bool isFastLocal,
  }) {
    if (!canUploadFileSize(fileSizeBytes)) return false;
    if (isFastLocal) return true;
    return canUseAiSmartGen();
  }

  /// Helper to require Pro before executing a feature.
  /// If the user is already Pro, executes immediately.
  /// Otherwise, presents the Paywall and returns whether purchase was completed.
  Future<bool> requirePro(
    BuildContext context, {
    String? featureName,
  }) async {
    if (isPro) return true;
    AppFeedback.selection();
    final upgraded = await context.router.push<bool>(
      PaywallRoute(),
    );
    return upgraded == true || isPro;
  }
}
