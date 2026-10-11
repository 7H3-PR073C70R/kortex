import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_active_pro_view.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_checkout_dock.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_desktop_panel.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_plan_content.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/promo_code_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-Screen Membership & Kortexify Pro Tier Screen.
/// Delivers an ultra-premium, high-converting experience with a persistent, sticky CTA dock.
@RoutePage(name: 'PaywallRoute')
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.onPurchaseSuccess,
    this.onClose,
    this.isEmbedded = false,
    this.isSlideOverlay = false,
    this.revenueCatService,
  });

  final VoidCallback? onPurchaseSuccess;
  final VoidCallback? onClose;
  final bool isEmbedded;
  final bool isSlideOverlay;
  final RevenueCatService? revenueCatService;

  static const String privacyPolicyUrl = 'https://kortexify.com/privacy';
  static const String termsOfServiceUrl = 'https://kortexify.com/terms';

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  CustomerInfo? _customerInfo;
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  int _selectedPlanIndex = 0; // 0 = Annual, 1 = Monthly

  RevenueCatService get _rcService =>
      widget.revenueCatService ?? RevenueCatService.instance;

  void _dismissPaywall([bool result = false]) {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }
    if (!mounted) return;
    if (context.router.canPop()) {
      context.router.pop(result);
    } else {
      unawaited(Navigator.of(context).maybePop(result));
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_fetchOfferings());
  }

  void _selectPlan(int index) {
    AppFeedback.selection();
    setState(() {
      _selectedPlanIndex = index;
      final offerings = _offerings;
      final offering =
          offerings?.current ??
          (offerings?.all.isNotEmpty == true
              ? offerings!.all.values.first
              : null);

      if (offering != null && offering.availablePackages.isNotEmpty) {
        if (index == 0) {
          // Annual
          _selectedPackage =
              offering.annual ??
              offering.availablePackages.firstWhere(
                (p) =>
                    p.packageType == PackageType.annual ||
                    p.identifier.toLowerCase().contains('annual') ||
                    p.identifier.toLowerCase().contains('year'),
                orElse: () => offering.availablePackages.first,
              );
        } else {
          // Monthly
          _selectedPackage =
              offering.monthly ??
              offering.availablePackages.firstWhere(
                (p) =>
                    p.packageType == PackageType.monthly ||
                    p.identifier.toLowerCase().contains('month'),
                orElse: () => offering.availablePackages.length > 1
                    ? offering.availablePackages[1]
                    : offering.availablePackages.first,
              );
        }
      }
    });
  }

  Future<void> _fetchOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await _rcService.fetchOfferings();
      CustomerInfo? customerInfo;
      if (_rcService.isInitialized) {
        try {
          customerInfo = await Purchases.getCustomerInfo();
        } on Object catch (e) {
          debugPrint('[PaywallScreen] Error fetching customer info: $e');
        }
      }
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _customerInfo = customerInfo;
          _isLoading = false;
        });
        _selectPlan(_selectedPlanIndex);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleManageSubscription() async {
    AppFeedback.selection();
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await _launchUrl('https://apps.apple.com/account/subscriptions');
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await _launchUrl('https://play.google.com/store/account/subscriptions');
    } else {
      await _launchUrl('https://kortexify.com/account');
    }
  }

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) {
      _selectPlan(_selectedPlanIndex);
    }

    final package = _selectedPackage;
    if (package == null) {
      if (!_rcService.isInitialized || _offerings == null) {
        if (kDebugMode) {
          context.read<AuthBloc>().add(
            const AuthSubscriptionUpdated(isPro: true),
          );
          context.read<AuthBloc>().add(const AuthProfileFetchRequested());
          context.showSnackBar(
            message: 'Pro Unlimited activated in sandbox mode 🎉',
            type: SnackBarType.success,
          );
          widget.onPurchaseSuccess?.call();
          _dismissPaywall(true);
          return;
        }

        context.showSnackBar(
          message: 'Unable to connect to app store products. Please try again.',
          type: SnackBarType.error,
        );
        return;
      }

      context.showSnackBar(
        message: 'Please select a subscription plan.',
        type: SnackBarType.error,
      );
      return;
    }

    AppFeedback.medium();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final success = await _rcService.purchasePackage(package);

      if (mounted) {
        if (success) {
          AppFeedback.celebration();
          context.read<AuthBloc>().add(
            const AuthSubscriptionUpdated(isPro: true),
          );
          context.read<AuthBloc>().add(const AuthProfileFetchRequested());
          context.showSnackBar(
            message: 'Welcome to Kortexify Pro Unlimited! 🎉',
            type: SnackBarType.success,
          );
          widget.onPurchaseSuccess?.call();
          _dismissPaywall(true);
        } else {
          context.showSnackBar(
            message: 'Purchase was cancelled or could not be completed.',
            type: SnackBarType.error,
          );
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        context.showSnackBar(
          message: 'Purchase failed: $e',
          type: SnackBarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    AppFeedback.selection();
    setState(() => _isProcessing = true);

    try {
      final success = await _rcService.restorePurchases();
      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          if (mounted) {
            context.read<AuthBloc>().add(
              const AuthSubscriptionUpdated(isPro: true),
            );
            context.read<AuthBloc>().add(const AuthProfileFetchRequested());
            context.showSnackBar(
              message: context.l10n.paywallRestoreSuccess,
              type: SnackBarType.success,
            );
            widget.onPurchaseSuccess?.call();
            _dismissPaywall(true);
          }
        } else {
          context.showSnackBar(
            message: context.l10n.paywallRestoreNoSub,
          );
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = context.l10n.restoreErrorPrefix('$e');
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handlePromoCodeRedemption() async {
    final redeemed = await PromoCodeModalSheet.show(context);
    if (redeemed == true && mounted) {
      widget.onPurchaseSuccess?.call();
      _dismissPaywall(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final size = MediaQuery.sizeOf(context);

    final authState = context.watch<AuthBloc>().state;
    final isPro = authState.isPro;
    final isWide = size.width >= 720;

    Widget buildProContent() {
      return PaywallActiveProView(
        colors: colors,
        typography: typography,
        l10n: l10n,
        isDark: isDark,
        authState: authState,
        customerInfo: _customerInfo,
        onReturnToKortex: () => _dismissPaywall(true),
        onManageSubscription: _handleManageSubscription,
        onOpenPrivacyPolicy: () => _launchUrl(PaywallScreen.privacyPolicyUrl),
        onOpenTermsOfService: () => _launchUrl(PaywallScreen.termsOfServiceUrl),
      );
    }

    Widget buildFreeContent({bool isInlineCheckout = false}) {
      return PaywallPlanContent(
        colors: colors,
        typography: typography,
        l10n: l10n,
        isDark: isDark,
        selectedPlanIndex: _selectedPlanIndex,
        onSelectPlan: _selectPlan,
        offerings: _offerings,
        isInlineCheckout: isInlineCheckout,
        isProcessing: _isProcessing,
        errorMessage: _errorMessage,
        onPurchase: _handlePurchase,
        onPromoCode: _handlePromoCodeRedemption,
        onOpenPrivacyPolicy: () => _launchUrl(PaywallScreen.privacyPolicyUrl),
        onOpenTermsOfService: () => _launchUrl(PaywallScreen.termsOfServiceUrl),
      );
    }

    // Embedded inside a parent detail panel (e.g. Profile detail panel)
    if (widget.isEmbedded) {
      return ColoredBox(
        color: colors.backgroundPrimary,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: AppLogoLoader(size: 56))
              : (isPro ? buildProContent() : buildFreeContent()),
        ),
      );
    }

    // Wide screen OR explicit slide-overlay mode:
    // Slide in as a right side panel (single column width ~520px)
    if (isWide || widget.isSlideOverlay) {
      final panelWidth = size.width >= 720 ? 520.0 : size.width;
      return PaywallDesktopPanel(
        colors: colors,
        typography: typography,
        l10n: l10n,
        isDark: isDark,
        isPro: isPro,
        isProcessing: _isProcessing,
        panelWidth: panelWidth,
        onDismiss: _dismissPaywall,
        onRestore: _handleRestore,
        child: _isLoading
            ? const Center(child: AppLogoLoader(size: 56))
            : (isPro ? buildProContent() : buildFreeContent(isInlineCheckout: true)),
      );
    }

    // Standard mobile portrait full-screen layout (< 720px)
    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return IconButton(
              icon: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isHovered
                      ? (isDark
                            ? colors.surfaceSecondary
                            : colors.surfacePrimary)
                      : (isDark
                            ? colors.surfaceSecondary.withAlpha(180)
                            : colors.surfacePrimary.withAlpha(200)),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isHovered
                        ? colors.primary.withAlpha(120)
                        : colors.surfaceBorder.withAlpha(80),
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: isHovered ? colors.primary : colors.textPrimary,
                  size: 18,
                ),
              ),
              onPressed: _dismissPaywall,
            );
          },
        ),
        actions: [
          if (!kIsWeb && !isPro)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return TextButton(
                    onPressed: _isProcessing ? null : _handleRestore,
                    child: Text(
                      l10n.paywallRestore,
                      style: typography.callout.bold.copyWith(
                        color: isHovered ? colors.textPrimary : colors.primary,
                        fontSize: 13,
                        decoration: isHovered
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_isLoading || isPro)
          ? null
          : Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: PaywallStickyBottomDock(
                  colors: colors,
                  typography: typography,
                  l10n: l10n,
                  isDark: isDark,
                  isProcessing: _isProcessing,
                  errorMessage: _errorMessage,
                  onPurchase: _handlePurchase,
                  onPromoCode: _handlePromoCodeRedemption,
                ),
              ),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: AppLogoLoader(size: 56))
            : (isPro ? buildProContent() : buildFreeContent()),
      ),
    );
  }
}
