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
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';

enum DeckExportFormat {
  csv,
  anki,
  pdfPrintable,
}

/// Centralized service for validating Kortex Pro entitlements,
/// enforcing feature boundaries, and presenting paywall upgrades.
class SubscriptionGuard {
  SubscriptionGuard({
    UserStorageService? userStorageService,
    LocalStorageService? localStorageService,
    RevenueCatService? revenueCatService,
  }) : _userStorage = userStorageService,
       _localStorage = localStorageService,
       _revenueCat = revenueCatService ?? RevenueCatService.instance;

  final UserStorageService? _userStorage;
  final LocalStorageService? _localStorage;
  final RevenueCatService _revenueCat;

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

  /// Cloud AI engines (Gemini/Edge Functions) require Pro.
  /// Local on-device GGUF inference is ALWAYS free for all users.
  bool canAccessCloudAi() => isPro;

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
      final lastDate =
          _effectiveLocalStorage.getPreference(key: PrefKeys.lastUploadDate);
      if (lastDate != todayStr) {
        return 0;
      }
      final countStr =
          _effectiveLocalStorage.getPreference(key: PrefKeys.dailyUploadCount);
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
