import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:kortex/src/core/services/user_storage_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Multi-Platform RevenueCat In-App Purchase Service for Kortex.
/// Supports iOS (StoreKit 2), Android (Google Play Billing v7+),
/// and Web (RevenueCat Web Billing via Stripe).
class RevenueCatService {
  RevenueCatService._();

  static final RevenueCatService instance = RevenueCatService._();

  static const String _webApiKey = 'rcb_your_revenuecat_web_stripe_key';
  static const String _androidApiKey = 'goog_your_play_console_key';
  static const String _appleApiKey = 'appl_your_app_store_key';

  static const String proEntitlementId = 'pro_access';

  final StreamController<bool> _entitlementStreamController =
      StreamController<bool>.broadcast();

  /// Reactive stream broadcasting whether the user has active Pro access.
  Stream<bool> get onEntitlementChanged => _entitlementStreamController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  static bool _isPlaceholderKey(String key) {
    if (key.trim().isEmpty) return true;
    final lower = key.toLowerCase();
    return lower.contains('your_') ||
        lower.contains('placeholder') ||
        lower.contains('todo') ||
        lower == 'rcb_your_revenuecat_web_stripe_key' ||
        lower == 'goog_your_play_console_key' ||
        lower == 'appl_your_app_store_key';
  }

  /// Initializes RevenueCat with the platform-specific API key and user ID.
  /// Gracefully handles missing or placeholder API keys in development/tests.
  Future<void> init(String userId) async {
    if (_isInitialized) {
      // Log in the user if the ID changed
      try {
        final info = await Purchases.logIn(userId);
        final isPro = info.customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
        _handleEntitlementUpdate(isPro);
        debugPrint(
          '[RevenueCatService] Logged in existing user: '
          '${info.customerInfo.originalAppUserId} (isPro: $isPro)',
        );
      } on Object catch (err) {
        debugPrint('[RevenueCatService] LogIn warning: $err');
      }
      return;
    }

    final apiKey = _resolveApiKey();
    if (_isPlaceholderKey(apiKey)) {
      debugPrint(
        '[RevenueCatService] Missing or placeholder API key ("$apiKey"). '
        'Skipping Purchases configuration safely.',
      );
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;
      await Purchases.configure(configuration);
      _isInitialized = true;
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        final isPro =
            customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
        _handleEntitlementUpdate(isPro);
      });
      unawaited(syncCustomerEntitlements());
      debugPrint(
        '[RevenueCatService] Configured successfully for user: $userId '
        '(isWeb: $kIsWeb)',
      );
    } on Object catch (e) {
      debugPrint('[RevenueCatService] Configuration error: $e');
    }
  }

  String _resolveApiKey() {
    if (kIsWeb) {
      final envKey = dotenv.isInitialized
          ? dotenv.env['REVENUECAT_WEB_API_KEY']
          : null;
      return (envKey != null && envKey.isNotEmpty) ? envKey : _webApiKey;
    }

    try {
      if (Platform.isAndroid) {
        final envKey = dotenv.isInitialized
            ? dotenv.env['REVENUECAT_GOOGLE_API_KEY']
            : null;
        return (envKey != null && envKey.isNotEmpty) ? envKey : _androidApiKey;
      } else if (Platform.isIOS || Platform.isMacOS) {
        final envKey = dotenv.isInitialized
            ? dotenv.env['REVENUECAT_APPLE_API_KEY']
            : null;
        return (envKey != null && envKey.isNotEmpty) ? envKey : _appleApiKey;
      }
    } on Object {
      // Fallback for non-supported or desktop targets
      return _appleApiKey;
    }

    return _appleApiKey;
  }

  /// Retrieves current active offerings and package tiers.
  Future<Offerings?> fetchOfferings() async {
    if (!_isInitialized) {
      debugPrint(
        '[RevenueCatService] Cannot fetch offerings: Not initialized',
      );
      return null;
    }

    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } on Object catch (e) {
      debugPrint('[RevenueCatService] Error fetching offerings: $e');
      return null;
    }
  }

  void _handleEntitlementUpdate(bool isPro) {
    try {
      if (locator.isRegistered<UserStorageService>()) {
        unawaited(locator<UserStorageService>().saveProStatus(isPro: isPro));
      }
      if (locator.isRegistered<AuthBloc>()) {
        locator<AuthBloc>().add(AuthSubscriptionUpdated(isPro: isPro));
      }
    } on Object catch (err) {
      debugPrint('[RevenueCatService] _handleEntitlementUpdate error: $err');
    }
    if (!_entitlementStreamController.isClosed) {
      _entitlementStreamController.add(isPro);
    }
  }

  /// Purchases a selected package across iOS, Android, or Web Stripe checkout.
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) {
      debugPrint('[RevenueCatService] Cannot purchase: Not initialized');
      return false;
    }

    try {
      final purchaseResult = await Purchases.purchase(
        PurchaseParams.package(package),
      );
      final customerInfo = purchaseResult.customerInfo;
      final isPro =
          customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
      _handleEntitlementUpdate(isPro);
      return isPro;
    } on PurchasesErrorCode catch (error) {
      if (error == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[RevenueCatService] User cancelled purchase.');
        return false;
      }
      debugPrint('[RevenueCatService] Purchase error code: $error');
      return false;
    } on Object catch (e) {
      debugPrint('[RevenueCatService] Generic purchase exception: $e');
      return false;
    }
  }

  /// Restores previous purchases on native platforms (iOS & Android).
  /// Web uses direct Stripe customer portal and email verification.
  Future<bool> restorePurchases() async {
    if (kIsWeb) {
      debugPrint(
        '[RevenueCatService] Restore purchases skipped on Web '
        '(Stripe-managed).',
      );
      return false;
    }

    if (!_isInitialized) {
      debugPrint('[RevenueCatService] Cannot restore: Not initialized');
      return false;
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPro =
          customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
      _handleEntitlementUpdate(isPro);
      return isPro;
    } on Object catch (e) {
      debugPrint('[RevenueCatService] Error restoring purchases: $e');
      return false;
    }
  }

  /// Checks if the active user possesses an active Pro entitlement.
  Future<bool> isProSubscriber() async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
    } on Object catch (e) {
      debugPrint('[RevenueCatService] Error getting customer info: $e');
      return false;
    }
  }

  /// Authoritatively synchronizes active entitlements from RevenueCat,
  /// updates local cache in [UserStorageService], and emits an event into [AuthBloc].
  Future<bool> syncCustomerEntitlements() async {
    final isPro = await isProSubscriber();
    _handleEntitlementUpdate(isPro);
    return isPro;
  }
}
