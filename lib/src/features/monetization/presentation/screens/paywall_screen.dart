import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Unified Adaptive Paywall Screen for Kortex.
/// Renders a responsive UI: sleek mobile sheet on iOS/Android,
/// and centered multi-column pricing layout on Web/Desktop.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.onPurchaseSuccess,
  });

  final VoidCallback? onPurchaseSuccess;

  static const String privacyPolicyUrl = 'https://kortexify.app/privacy';
  static const String termsOfServiceUrl = 'https://kortexify.app/terms';

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  bool _isProcessing = false;
  Offerings? _offerings;
  Package? _selectedPackage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadOfferings());
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offerings = await RevenueCatService.instance.fetchOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          _selectedPackage = offerings?.current?.annual ??
              offerings?.current?.monthly ??
              offerings?.current?.availablePackages.firstOrNull;
          _isLoading = false;
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load subscription plans: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePurchase() async {
    final package = _selectedPackage;
    if (package == null) return;

    setState(() => _isProcessing = true);

    try {
      final success = await RevenueCatService.instance.purchasePackage(package);
      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          widget.onPurchaseSuccess?.call();
          await Navigator.of(context).maybePop(true);
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Purchase error: $e';
        });
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.paywallRestoreSuccess,
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          widget.onPurchaseSuccess?.call();
          await Navigator.of(context).maybePop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.paywallRestoreNoSub),
            ),
          );
        }
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Restore error: $e';
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
    final isDesktopOrWeb = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.of(context).maybePop(false),
        ),
        actions: [
          if (!kIsWeb)
            TextButton(
              onPressed: _isProcessing ? null : _handleRestore,
              child: const Text(
                'Restore',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            : isDesktopOrWeb
                ? _buildWebDesktopLayout()
                : _buildMobileLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          SizedBox(height: 24.h),
          _buildFeatureList(),
          SizedBox(height: 28.h),
          _buildPackageSelector(),
          SizedBox(height: 24.h),
          _buildCtaButton(),
          SizedBox(height: 20.h),
          _buildComplianceFooter(),
        ],
      ),
    );
  }

  Widget _buildWebDesktopLayout() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildFeatureList()),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPackageSelector(),
                        const SizedBox(height: 24),
                        _buildCtaButton(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildComplianceFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt, color: Color(0xFF818CF8), size: 16),
              SizedBox(width: 6.w),
              const Text(
                'KORTEXIFY PRO UNLIMITED',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Instant OCR extraction, unlimited DeepSeek AI streaming, '
          'and automated FSRS scheduling.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 13.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureList() {
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
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: features
            .map(
              (f) => Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
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

  Widget _buildPackageSelector() {
    final packages = _offerings?.current?.availablePackages ?? [];

    if (packages.isEmpty) {
      // Fallback display card if offerings are currently syncing
      return Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6366F1)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pro Annual Access',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            Text(
              r'$4.99 / mo',
              style: TextStyle(
                color: Color(0xFF818CF8),
                fontWeight: FontWeight.bold,
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
                  ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                  : const Color(0xFF1E293B).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFF334155),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected
                      ? const Color(0xFF818CF8)
                      : Colors.white38,
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
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'SAVE 45%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
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
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  pkg.storeProduct.priceString,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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

  Widget _buildCtaButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFEF4444),
              fontSize: 12,
            ),
          ),
          SizedBox(height: 8.h),
        ],
        ElevatedButton(
          onPressed: _isProcessing ? null : _handlePurchase,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 4,
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
                  kIsWeb
                      ? 'Continue to Checkout'
                      : 'Unlock Kortexify Pro',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildComplianceFooter() {
    return Column(
      children: [
        Text(
          'Subscriptions renew automatically unless cancelled at least '
          '24 hours before the end of the current billing cycle.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white38,
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
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 11,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Text(
              ' • ',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
            GestureDetector(
              onTap: () => _launchUrl(PaywallScreen.termsOfServiceUrl),
              child: const Text(
                'Terms of Use (EULA)',
                style: TextStyle(
                  color: Color(0xFF818CF8),
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
