import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class _ProFeatureItem {
  const _ProFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Full-Screen Membership & Kortexify Pro Tier Screen.
/// Delivers an ultra-premium experience aligned with Kortex's dark aesthetic.
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

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _errorMessage;
  int _selectedPlanIndex = 0; // 0 = Annual, 1 = Monthly

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    unawaited(_glowController.repeat(reverse: true));

    _glowAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    unawaited(_fetchOfferings());
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _fetchOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await RevenueCatService.instance.fetchOfferings();
      if (mounted) {
        setState(() {
          _selectedPackage = offerings?.current?.annual ??
              offerings?.current?.availablePackages.firstOrNull;
          _isLoading = false;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePurchase() async {
    AppFeedback.medium();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      if (_selectedPackage != null) {
        await RevenueCatService.instance.purchasePackage(_selectedPackage!);
      }

      if (mounted) {
        context.read<AuthBloc>().add(const AuthProfileFetchRequested());
        context.showSnackBar(
          message: 'Welcome to Kortexify Pro Unlimited! 🎉',
          type: SnackBarType.success,
        );
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
    AppFeedback.selection();
    setState(() => _isProcessing = true);

    try {
      final success = await RevenueCatService.instance.restorePurchases();
      if (mounted) {
        setState(() => _isProcessing = false);
        if (success) {
          if (mounted) {
            context.read<AuthBloc>().add(const AuthProfileFetchRequested());
            context.showSnackBar(
              message: context.l10n.paywallRestoreSuccess,
              type: SnackBarType.success,
            );
            widget.onPurchaseSuccess?.call();
            await Navigator.of(context).maybePop(true);
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

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: colors.textPrimary,
            size: 22,
          ),
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
                  fontSize: 13,
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
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20.w,
                  vertical: 8.h,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroHeader(colors, typography, isDark),
                    SizedBox(height: 24.h),
                    _buildFeatureMatrix(colors, typography, isDark),
                    SizedBox(height: 24.h),
                    _buildTierPlansSelector(colors, typography, isDark),
                    SizedBox(height: 24.h),
                    _buildCtaButton(colors, typography, isDark),
                    SizedBox(height: 20.h),
                    _buildFooter(colors, typography, l10n),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildHeroHeader(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            final alphaPrimary = (80 * _glowAnimation.value).toInt();
            final alphaAccent = (60 * _glowAnimation.value).toInt();
            final shadowAlpha = (40 * _glowAnimation.value).toInt();

            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 6.h,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colors.primary.withAlpha(alphaPrimary),
                    colors.syllabotAccent.withAlpha(alphaAccent),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.primary.withAlpha(120),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withAlpha(shadowAlpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'KORTEXIFY PRO SCHOLAR',
                    style: typography.caption.bold.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        SizedBox(height: 14.h),
        Text(
          'Supercharge Your Academic Mastery',
          textAlign: TextAlign.center,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22.sp,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          'Unlimited Syllabot AI reasoning, instant multimodal Document OCR, '
          'and cloud-synced FSRS spaced repetition.',
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 12.5.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureMatrix(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    const features = [
      _ProFeatureItem(
        icon: Icons.psychology_rounded,
        title: 'Unlimited Syllabot AI Reasoning',
        subtitle: 'Deep Socratic tutoring without token limits',
      ),
      _ProFeatureItem(
        icon: Icons.document_scanner_rounded,
        title: 'Instant Multimodal OCR Drop',
        subtitle: 'Convert textbooks, notes & past papers instantly',
      ),
      _ProFeatureItem(
        icon: Icons.auto_mode_rounded,
        title: 'FSRS Spaced Repetition Engine',
        subtitle: 'High-retention memory scheduling',
      ),
      _ProFeatureItem(
        icon: Icons.cloud_sync_rounded,
        title: 'Seamless Cloud Backup & Sync',
        subtitle: 'Zero-latency sync across all your devices',
      ),
      _ProFeatureItem(
        icon: Icons.download_rounded,
        title: 'Anki, CSV & Study Sheets Export',
        subtitle: 'Full data portability with study notes',
      ),
    ];

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colors.surfaceSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 90 : 60),
        ),
      ),
      child: Column(
        children: features
            .map(
              (f) => Padding(
                padding: EdgeInsets.symmetric(vertical: 6.h),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        f.icon,
                        color: colors.primary,
                        size: 18,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.title,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13.sp,
                            ),
                          ),
                          Text(
                            f.subtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF10B981),
                      size: 18,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTierPlansSelector(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
  ) {
    return Column(
      children: [
        // Annual Plan Card (Selected / Featured)
        ShrinkableButton(
          onTap: () => setState(() => _selectedPlanIndex = 0),
          child: Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: _selectedPlanIndex == 0
                  ? colors.primary.withAlpha(isDark ? 40 : 20)
                  : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _selectedPlanIndex == 0
                    ? colors.primary
                    : colors.surfaceBorder.withAlpha(80),
                width: _selectedPlanIndex == 0 ? 2 : 1,
              ),
              boxShadow: _selectedPlanIndex == 0
                  ? [
                      BoxShadow(
                        color: colors.primary.withAlpha(30),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPlanIndex == 0
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: _selectedPlanIndex == 0
                      ? colors.primary
                      : colors.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Annual Pass',
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14.5.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'SAVE 45%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        r'Billed annually at $59.99 / yr (approx. $4.99 / mo)',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  r'$4.99',
                  style: typography.title3.bold.copyWith(
                    color: colors.primary,
                    fontSize: 18.sp,
                  ),
                ),
                Text(
                  '/mo',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),

        // Monthly Plan Card
        ShrinkableButton(
          onTap: () => setState(() => _selectedPlanIndex = 1),
          child: Container(
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: _selectedPlanIndex == 1
                  ? colors.primary.withAlpha(isDark ? 40 : 20)
                  : colors.surfaceSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _selectedPlanIndex == 1
                    ? colors.primary
                    : colors.surfaceBorder.withAlpha(80),
                width: _selectedPlanIndex == 1 ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedPlanIndex == 1
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: _selectedPlanIndex == 1
                      ? colors.primary
                      : colors.textSecondary,
                  size: 20,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Pass',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14.5.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        'Flexible billing, cancel anytime',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  r'$8.99',
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 17.sp,
                  ),
                ),
                Text(
                  '/mo',
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCtaButton(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    bool isDark,
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
        ShrinkableButton(
          onTap: _isProcessing ? null : _handlePurchase,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.syllabotAccent,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(isDark ? 100 : 60),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
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
                      'Unlock Kortexify Pro Access',
                      style: typography.body.bold.copyWith(
                        color: Colors.white,
                        fontSize: 15.sp,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Text(
          'Subscriptions renew automatically unless cancelled at least '
          '24 hours before the end of the current billing period.',
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary.withAlpha(120),
            fontSize: 10.5.sp,
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
                  decorationColor: colors.primary.withAlpha(180),
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
            ),
            Text(
              ' • ',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary.withAlpha(120),
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
                  decorationColor: colors.primary.withAlpha(180),
                  decorationStyle: TextDecorationStyle.solid,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
