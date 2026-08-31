import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
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

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initializes RevenueCat with the platform-specific API key and user ID.
  Future<void> init(String userId) async {
    if (_isInitialized) {
      // Log in the user if the ID changed
      try {
        final info = await Purchases.logIn(userId);
        debugPrint(
          '[RevenueCatService] Logged in existing user: '
          '${info.customerInfo.originalAppUserId}',
        );
      } on Object catch (err) {
        debugPrint('[RevenueCatService] LogIn warning: $err');
      }
      return;
    }

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      debugPrint(
        '[RevenueCatService] No API Key resolved for current platform',
      );
      return;
    }

    try {
      final configuration = PurchasesConfiguration(apiKey)..appUserID = userId;
      await Purchases.configure(configuration);
      _isInitialized = true;
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
      return _webApiKey;
    }

    try {
      if (Platform.isAndroid) {
        return _androidApiKey;
      } else if (Platform.isIOS || Platform.isMacOS) {
        return _appleApiKey;
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
      return customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
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
      return customerInfo.entitlements.all[proEntitlementId]?.isActive ?? false;
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
}
