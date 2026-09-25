import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_event.dart';
import 'package:kortex/src/features/monetization/data/datasources/revenuecat_service.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/promo_code_modal_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';

import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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
/// Delivers an ultra-premium, high-converting experience with a persistent, sticky CTA dock.
@RoutePage(name: 'PaywallRoute')
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
  int _selectedPlanIndex = 0; // 0 = Annual, 1 = Monthly

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
      final offerings = await RevenueCatService.instance.fetchOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
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

  Future<void> _handlePurchase() async {
    if (_selectedPackage == null) {
      _selectPlan(_selectedPlanIndex);
    }

    final package = _selectedPackage;
    if (package == null) {
      if (!RevenueCatService.instance.isInitialized || _offerings == null) {
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
          await Navigator.of(context).maybePop(true);
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
      final success = await RevenueCatService.instance.purchasePackage(package);

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
          await Navigator.of(context).maybePop(true);
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
      final success = await RevenueCatService.instance.restorePurchases();
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

  Future<void> _handlePromoCodeRedemption() async {
    final redeemed = await PromoCodeModalSheet.show(context);
    if (redeemed == true && mounted) {
      widget.onPurchaseSuccess?.call();
      Navigator.of(context).pop(true);
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
        backgroundColor: colors.backgroundPrimary,

        elevation: 0,
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
              onPressed: () => Navigator.of(context).maybePop(false),
            );
          },
        ),
        actions: [
          if (!kIsWeb)
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return TextButton(
                    onPressed: _isProcessing ? null : _handleRestore,
                    child: Text(
                      l10n.paywallRestore,
                      style: typography.callout.bold.copyWith(
                        color: isHovered ? colors.textPrimary : colors.primary,
                        fontSize: 13.sp,
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
      // Persistent Sticky Bottom Dock ensures primary CTA and promo code are always 1-tap accessible
      bottomNavigationBar: _isLoading
          ? null
          : Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: _buildStickyBottomDock(
                  colors,
                  typography,
                  l10n,
                  isDark,
                ),
              ),
            ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: AppLogoLoader(size: 56),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 4.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children:
                          [
                                _buildHeroHeader(
                                  colors,
                                  typography,
                                  l10n,
                                  isDark,
                                ),
                                SizedBox(height: 14.h),
                                _buildSocialProofStrip(
                                  colors,
                                  typography,
                                  l10n,
                                  isDark,
                                ),
                                SizedBox(height: 18.h),
                                _buildTierPlansSelector(
                                  colors,
                                  typography,
                                  l10n,
                                  isDark,
                                ),
                                SizedBox(height: 16.h),
                                _buildTransparentTimeline(
                                  colors,
                                  typography,
                                  l10n,
                                  isDark,
                                ),
                                SizedBox(height: 18.h),
                                _buildFeatureMatrix(
                                  colors,
                                  typography,
                                  l10n,
                                  isDark,
                                ),
                                SizedBox(height: 16.h),
                                _buildFooter(colors, typography, l10n),
                                SizedBox(height: 16.h),
                              ]
                              .animate(interval: 80.ms)
                              .fadeIn(
                                duration: 300.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .slideY(
                                begin: 0.05,
                                end: 0,
                                duration: 300.ms,
                                curve: Curves.easeOutCubic,
                              ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeroHeader(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 14.w,
            vertical: 6.h,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withAlpha(80),
                colors.syllabotAccent.withAlpha(60),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.primary.withAlpha(140),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 40 : 15),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colors.warning,
                size: 15,
              ),
              SizedBox(width: 6.w),
              Text(
                l10n.paywallScholarBadge,
                style: typography.caption.bold.copyWith(
                  color: colors.white,
                  fontSize: 11.sp,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10.h),
        Text(
          l10n.paywallHeroTitle,
          textAlign: TextAlign.center,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22.sp,
            height: 1.2,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          l10n.paywallHeroSubtitle,
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 12.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialProofStrip(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(140)
            : colors.surfacePrimary.withAlpha(180),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: _buildTrustBadge(
              icon: Icons.school_rounded,
              iconColor: colors.success,
              label: l10n.paywallSocialProofRetention,
              colors: colors,
              typography: typography,
            ),
          ),
          Container(
            width: 1,
            height: 16.h,
            color: colors.surfaceBorder.withAlpha(90),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildTrustBadge(
                icon: Icons.bolt_rounded,
                iconColor: colors.primary,
                label: l10n.paywallSocialProofSpeed,
                colors: colors,
                typography: typography,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge({
    required IconData icon,
    required Color iconColor,
    required String label,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 15),
        SizedBox(width: 4.w),
        Flexible(
          child: Text(
            label,
            style: typography.footnote.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 10.5.sp,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierPlansSelector(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Column(
      children: [
        // Annual Plan Card (Featured & Best Value)
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final isSelected = _selectedPlanIndex == 0;
            return ShrinkableButton(
              onTap: () => _selectPlan(0),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 45)
                              : (isHovered ? 32 : 22),
                        )
                      : (isHovered
                            ? (isDark
                                  ? colors.surfaceSecondary.withAlpha(220)
                                  : colors.surfacePrimary)
                            : (isDark
                                  ? colors.surfaceSecondary.withAlpha(180)
                                  : colors.surfacePrimary.withAlpha(200))),
                  borderRadius: AppRadius.radiusPanel,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : (isHovered
                              ? colors.primary.withAlpha(140)
                              : colors.surfaceBorder.withAlpha(80)),
                    width: isSelected ? 2 : (isHovered ? 1.4 : 1.0),
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 45)
                              : (isHovered ? 30 : 15),
                        ),
                        blurRadius: isHovered ? 18 : 14,
                        offset: Offset(0, isHovered ? 5 : 4),
                      )
                    else if (isHovered)
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? colors.primary : colors.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  l10n.paywallAnnualPlanTitle,
                                  style: typography.body.bold.copyWith(
                                    color: colors.textPrimary,
                                    fontSize: 14.5.sp,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.success,
                                      colors.success.withAlpha(200),
                                    ],
                                  ),
                                  borderRadius: AppRadius.radiusBadge,
                                ),
                                child: Text(
                                  l10n.paywallAnnualSaveBadge,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 8.5.sp,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            l10n.paywallAnnualPlanSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            l10n.paywallAnnualWeeklyNote,
                            style: typography.footnote.medium.copyWith(
                              color: colors.primary,
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              r'$4.99',
                              style: typography.title3.bold.copyWith(
                                color: colors.primary,
                                fontSize: 18.sp,
                              ),
                            ),
                            Text(
                              l10n.paywallPerMonth,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10.5.sp,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          r'$8.99/mo',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary.withAlpha(120),
                            decoration: TextDecoration.lineThrough,
                            fontSize: 10.5.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        SizedBox(height: 8.h),

        // Monthly Plan Card
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final isSelected = _selectedPlanIndex == 1;
            return ShrinkableButton(
              onTap: () => _selectPlan(1),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 45)
                              : (isHovered ? 32 : 22),
                        )
                      : (isHovered
                            ? (isDark
                                  ? colors.surfaceSecondary.withAlpha(220)
                                  : colors.surfacePrimary)
                            : (isDark
                                  ? colors.surfaceSecondary.withAlpha(180)
                                  : colors.surfacePrimary.withAlpha(200))),
                  borderRadius: AppRadius.radiusPanel,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : (isHovered
                              ? colors.primary.withAlpha(140)
                              : colors.surfaceBorder.withAlpha(80)),
                    width: isSelected ? 2 : (isHovered ? 1.4 : 1.0),
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 45)
                              : (isHovered ? 30 : 15),
                        ),
                        blurRadius: isHovered ? 18 : 14,
                        offset: Offset(0, isHovered ? 5 : 4),
                      )
                    else if (isHovered)
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 50 : 15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      color: isSelected ? colors.primary : colors.textSecondary,
                      size: 20,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.paywallMonthlyPlanTitle,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14.5.sp,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            l10n.paywallMonthlyPlanSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          r'$8.99',
                          style: typography.title3.bold.copyWith(
                            color: isSelected
                                ? colors.primary
                                : colors.textPrimary,
                            fontSize: 17.sp,
                          ),
                        ),
                        Text(
                          l10n.paywallPerMonth,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10.5.sp,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTransparentTimeline(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(120)
            : colors.surfacePrimary.withAlpha(160),
        borderRadius: AppRadius.radiusPanel,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          _buildTimelineItem(
            step: '1',
            label: l10n.paywallTimelineToday,
            colors: colors,
            typography: typography,
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textSecondary.withAlpha(100),
            size: 15,
          ),
          _buildTimelineItem(
            step: '2',
            label: l10n.paywallTimelineBilling,
            colors: colors,
            typography: typography,
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.textSecondary.withAlpha(100),
            size: 15,
          ),
          _buildTimelineItem(
            step: '3',
            label: l10n.paywallTimelineCancel,
            colors: colors,
            typography: typography,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String step,
    required String label,
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
  }) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: typography.footnote.bold.copyWith(
                  color: colors.primary,
                  fontSize: 8.5.sp,
                ),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 9.sp,
                height: 1.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureMatrix(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final features = [
      _ProFeatureItem(
        icon: Icons.psychology_rounded,
        title: l10n.paywallFeature1Title,
        subtitle: l10n.paywallFeature1Subtitle,
      ),
      _ProFeatureItem(
        icon: Icons.document_scanner_rounded,
        title: l10n.paywallFeature2Title,
        subtitle: l10n.paywallFeature2Subtitle,
      ),
      _ProFeatureItem(
        icon: Icons.auto_mode_rounded,
        title: l10n.paywallFeature3Title,
        subtitle: l10n.paywallFeature3Subtitle,
      ),
      _ProFeatureItem(
        icon: Icons.cloud_sync_rounded,
        title: l10n.paywallFeature4Title,
        subtitle: l10n.paywallFeature4Subtitle,
      ),
      _ProFeatureItem(
        icon: Icons.download_rounded,
        title: l10n.paywallFeature5Title,
        subtitle: l10n.paywallFeature5Subtitle,
      ),
    ];

    return ClipRRect(
      borderRadius: AppRadius.radiusDialog,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(200)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(isDark ? 90 : 60),
            ),
          ),
          child: Column(
            children: features
                .map(
                  (f) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 5.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary.withAlpha(28),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Icon(
                            f.icon,
                            color: colors.primary,
                            size: 16,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                f.title,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 12.5.sp,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                f.subtitle,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10.5.sp,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Icon(
                          Icons.check_circle_rounded,
                          color: colors.success,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// Pinned bottom action bar containing the primary CTA, guarantee, and promo code entry.
  /// Guarantees instant 1-tap access with zero scrolling.
  Widget _buildStickyBottomDock(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(245)
            : colors.surfacePrimary.withAlpha(250),
        border: Border(
          top: BorderSide(
            color: colors.surfaceBorder.withAlpha(isDark ? 100 : 70),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 140 : 30),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: typography.caption.medium.copyWith(
                    color: colors.error,
                    fontSize: 11.5.sp,
                  ),
                ),
                SizedBox(height: 6.h),
              ],
              PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return ShrinkableButton(
                    onTap: _isProcessing ? null : _handlePurchase,
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colors.primary,
                            if (isHovered)
                              colors.syllabotAccent.withAlpha(240)
                            else
                              colors.syllabotAccent,
                          ],
                        ),
                        borderRadius: AppRadius.radiusPanel,
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(
                              isDark
                                  ? (isHovered ? 80 : 55)
                                  : (isHovered ? 45 : 25),
                            ),
                            blurRadius: isHovered ? 20 : 16,
                            offset: Offset(0, isHovered ? 6 : 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const AppLogoLoader(
                                size: 20,
                                showMessage: false,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.lock_open_rounded,
                                    color: colors.white,
                                    size: 17,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    l10n.paywallCtaButton,
                                    style: typography.body.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 15.sp,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox(height: 6.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 11.sp,
                    color: colors.textSecondary.withAlpha(150),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    l10n.paywallSecurityGuarantee,
                    textAlign: TextAlign.center,
                    style: typography.footnote.medium.copyWith(
                      color: colors.textSecondary.withAlpha(160),
                      fontSize: 10.5.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2.h),
              Center(
                child: PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      onTap: _isProcessing ? null : _handlePromoCodeRedemption,
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          vertical: 4.h,
                          horizontal: 8.w,
                        ),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? colors.primary.withAlpha(25)
                              : context.colors.transparent,
                          borderRadius: AppRadius.radiusBadge,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.card_giftcard_rounded,
                              size: 14.sp,
                              color: colors.primary,
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              l10n.paywallHavePromoCode,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
          l10n.paywallAutoRenewDisclaimer,
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary.withAlpha(120),
            fontSize: 10.sp,
            height: 1.35,
          ),
        ),
        SizedBox(height: 8.h),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            GestureDetector(
              onTap: () => _launchUrl(PaywallScreen.privacyPolicyUrl),
              child: Text(
                l10n.privacyPolicy,
                style: typography.caption.medium.copyWith(
                  color: colors.primary,
                  fontSize: 10.5.sp,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primary.withAlpha(180),
                ),
              ),
            ),
            Text(
              '•',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary.withAlpha(120),
                fontSize: 10.5.sp,
              ),
            ),
            GestureDetector(
              onTap: () => _launchUrl(PaywallScreen.termsOfServiceUrl),
              child: Text(
                l10n.termsOfService,
                style: typography.caption.medium.copyWith(
                  color: colors.primary,
                  fontSize: 10.5.sp,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primary.withAlpha(180),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
