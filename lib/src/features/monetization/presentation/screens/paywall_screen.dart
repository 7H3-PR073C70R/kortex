import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-Screen RevenueCat In-App Purchase & Web Paywall Modal.
/// Provides frictionless subscription selection, native StoreKit/PlayBilling
/// purchase flow, and web Stripe routing.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.onPurchaseSuccess,
  });

  final VoidCallback? onPurchaseSuccess;

  static const String privacyPolicyUrl = 'https://kortexify.com/privacy';
  static const String termsOfServiceUrl = 'https://kortexify.com/terms';

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchOfferings());
  }

  Future<void> _fetchOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await RevenueCatService.instance.fetchOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _selectedPackage = offerings?.current?.annual ??
              offerings?.current?.availablePackages.firstOrNull;
          _isLoading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final success = await RevenueCatService.instance
          .purchasePackage(_selectedPackage!);
      if (success && mounted) {
        widget.onPurchaseSuccess?.call();
        await Navigator.of(context).maybePop(true);
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isProcessing = true);

    try {
      final success = await RevenueCatService.instance.restorePurchases();
      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          context.showSnackBar(
            message: context.l10n.paywallRestoreSuccess,
          );
          widget.onPurchaseSuccess?.call();
          await Navigator.of(context).maybePop(true);
        } else {
          context.showSnackBar(
            message: context.l10n.paywallRestoreNoSub,
            type: SnackBarType.info,
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final isDesktopOrWeb = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor:
          isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textSecondary),
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        actions: [
          if (!kIsWeb)
            TextButton(
              onPressed: _isProcessing ? null : _handleRestore,
              child: Text(
                l10n.paywallRestore,
                style: typography.callout.semiBold.copyWith(
                  color: colors.primary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: colors.primary),
              )
            : isDesktopOrWeb
                ? _buildWebDesktopLayout(colors, typography, l10n, isDark)
                : _buildMobileLayout(colors, typography, l10n, isDark),
      ),
    );
  }

  Widget _buildMobileLayout(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(colors, typography, isDark),
          SizedBox(height: 24.h),
          _buildFeatureList(colors, typography, isDark),
          SizedBox(height: 28.h),
          _buildPackageSelector(colors, typography, isDark),
          SizedBox(height: 24.h),
          _buildCtaButton(colors, typography),
          SizedBox(height: 20.h),
          _buildComplianceFooter(colors, typography, l10n),
        ],
      ),
    );
  }

  Widget _buildWebDesktopLayout(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(colors, typography, isDark),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildFeatureList(colors, typography, isDark),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPackageSelector(colors, typography, isDark),
                        const SizedBox(height: 24),
                        _buildCtaButton(colors, typography),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildComplianceFooter(colors, typography, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colors.primary.withAlpha(90),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: colors.primary, size: 16),
              SizedBox(width: 6.w),
              Text(
                'KORTEXIFY PRO UNLIMITED',
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'Master Any Subject in Minutes',
          textAlign: TextAlign.center,
          style: typography.headline.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 24.sp,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Instant OCR extraction, unlimited DeepSeek AI streaming, '
          'and automated FSRS scheduling.',
          textAlign: TextAlign.center,
          style: typography.body.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 13.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final features = [
      'Unlimited Document Ingestion (PDF, Scans, Notes)',
      'High-Speed DeepSeek V4 Pro Reasoning Engine',
      'Advanced FSRS Spaced Repetition Scheduling',
      'Local-First Offline Study & Auto-Sync',
      'Export to Anki, Markdown & PDF Sheets',
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.surfaceBorder),
      ),
      child: Column(
        children: features
            .map(
              (f) => Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: colors.success,
                      size: 18,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        f,
                        style: typography.subhead.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildPackageSelector(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    final packages = _offerings?.current?.availablePackages ?? [];

    if (packages.isEmpty) {
      // Fallback display card if offerings are currently syncing
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary
              : colors.surfaceSecondary.withAlpha(120),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pro Annual Access',
              style: typography.body.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 15,
              ),
            ),
            Text(
              r'$4.99 / mo',
              style: typography.body.bold.copyWith(
                color: colors.primary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: packages.map((pkg) {
        final isSelected = _selectedPackage?.identifier == pkg.identifier;
        final isAnnual = pkg.packageType == PackageType.annual;

        return GestureDetector(
          onTap: () => setState(() => _selectedPackage = pkg),
          child: Container(
            margin: EdgeInsets.only(bottom: 12.h),
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withAlpha(35)
                  : (isDark
                      ? colors.surfaceSecondary
                      : colors.surfaceSecondary.withAlpha(90)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? colors.primary : colors.surfaceBorder,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? colors.primary : colors.textMuted,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            pkg.storeProduct.title.isNotEmpty
                                ? pkg.storeProduct.title
                                : (isAnnual ? 'Annual Pass' : 'Monthly Pass'),
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14.sp,
                            ),
                          ),
                          if (isAnnual) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color: colors.success,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SAVE 45%',
                                style: typography.caption.bold.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        pkg.storeProduct.description.isNotEmpty
                            ? pkg.storeProduct.description
                            : (isAnnual
                                ? 'Billed annually, cancel anytime'
                                : 'Billed monthly, cancel anytime'),
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  pkg.storeProduct.priceString,
                  style: typography.subhead.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 15.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCtaButton(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: typography.caption.medium.copyWith(
              color: colors.error,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        ElevatedButton(
          onPressed: _isProcessing ? null : _handlePurchase,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
          ),
          child: _isProcessing
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  kIsWeb ? 'Continue to Checkout' : 'Unlock Kortexify Pro',
                  style: typography.body.bold.copyWith(
                    color: Colors.white,
                    fontSize: 15.sp,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildComplianceFooter(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Text(
          'Subscriptions renew automatically unless cancelled at least '
          '24 hours before the end of the current billing cycle.',
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textMuted,
            fontSize: 10.sp,
            height: 1.4,
          ),
        ),
        SizedBox(height: 10.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _launchUrl(PaywallScreen.privacyPolicyUrl),
              child: Text(
                l10n.privacyPolicy,
                style: typography.caption.medium.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Text(
              ' • ',
              style: typography.caption.regular.copyWith(
                color: colors.textMuted,
                fontSize: 11,
              ),
            ),
            GestureDetector(
              onTap: () => _launchUrl(PaywallScreen.termsOfServiceUrl),
              child: Text(
                l10n.termsOfService,
                style: typography.caption.medium.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
