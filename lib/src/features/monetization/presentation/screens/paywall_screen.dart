import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    this.onClose,
    this.isEmbedded = false,
    this.isSlideOverlay = false,
  });

  final VoidCallback? onPurchaseSuccess;
  final VoidCallback? onClose;
  final bool isEmbedded;
  final bool isSlideOverlay;

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

  Widget _buildDesktopPanelHeader(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return IconButton(
                icon: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? (isDark ? colors.surfaceSecondary : colors.surfacePrimary)
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
          const SizedBox(width: 8),
          Text(
            'Kortexify Pro',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          if (!kIsWeb)
            TextButton(
              onPressed: _isProcessing ? null : _handleRestore,
              child: Text(
                l10n.paywallRestore,
                style: typography.callout.bold.copyWith(
                  color: colors.primary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopPanelBody(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroHeader(colors, typography, l10n, isDark),
          const SizedBox(height: 14),
          _buildSocialProofStrip(colors, typography, l10n, isDark),
          const SizedBox(height: 16),
          _buildTierPlansSelector(colors, typography, l10n, isDark),
          const SizedBox(height: 14),
          _buildTransparentTimeline(colors, typography, l10n, isDark),
          const SizedBox(height: 16),
          _buildCheckoutControls(
            colors: colors,
            typography: typography,
            l10n: l10n,
            isDark: isDark,
            isInline: true,
          ),
          const SizedBox(height: 16),
          _buildFeatureMatrix(colors, typography, l10n, isDark),
          const SizedBox(height: 16),
          _buildFooter(colors, typography, l10n),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final size = MediaQuery.sizeOf(context);

    final isLandscape = size.width > size.height;
    final isWide = size.width >= 720;
    final useTwoColumnLayout = (isLandscape && size.width >= 560) || isWide;
    final isDesktop = size.width >= 900;

    // Embedded inside a parent detail panel (e.g. Profile detail panel on desktop)
    if (widget.isEmbedded) {
      return ColoredBox(
        color: colors.backgroundPrimary,
        child: SafeArea(
          child: _isLoading
              ? const Center(child: AppLogoLoader(size: 56))
              : (useTwoColumnLayout
                  ? _buildTwoColumnLayout(colors, typography, l10n, isDark, size)
                  : _buildOneColumnLayout(colors, typography, l10n, isDark)),
        ),
      );
    }

    // Slide-in drawer overlay mode (for quick feature gate popups on desktop)
    if (widget.isSlideOverlay && isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Ambient Dimmed Backdrop Overlay with opaque hit testing for auto-closing
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _dismissPaywall,
                child: ColoredBox(
                  color: Colors.black.withAlpha(isDark ? 140 : 80),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),

            // Right Slide-in Compact Panel (Width 520px)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 520,
              child: Material(
                elevation: 16,
                color: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
                shape: Border(
                  left: BorderSide(
                    color: colors.primary.withAlpha(isDark ? 80 : 50),
                    width: 1.5,
                  ),
                ),
                child: SafeArea(
                  child: Focus(
                    autofocus: true,
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent &&
                          event.logicalKey == LogicalKeyboardKey.escape) {
                        _dismissPaywall();
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: Column(
                      children: [
                        _buildDesktopPanelHeader(colors, typography, l10n, isDark),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colors.surfaceBorder.withAlpha(isDark ? 50 : 80),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: AppLogoLoader(size: 56))
                              : _buildDesktopPanelBody(colors, typography, l10n, isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              )
                  .animate()
                  .slideX(
                    begin: 1,
                    end: 0,
                    duration: 320.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(duration: 200.ms),
            ),
          ],
        ),
      );
    }

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
          if (!kIsWeb)
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
      // In 1-column mobile portrait, use the sticky bottom dock.
      // In 2-column landscape/desktop, the checkout controls are integrated inline in the right column.
      bottomNavigationBar: (_isLoading || useTwoColumnLayout)
          ? null
          : Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
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
            : Stack(
                children: [
                  // Subtle ambient background breathing orb for depth
                  _buildAmbientBackgroundOrbs(colors, isDark, isLandscape),

                  // Main Content Layout
                  if (useTwoColumnLayout)
                    _buildTwoColumnLayout(
                      colors,
                      typography,
                      l10n,
                      isDark,
                      size,
                    )
                  else
                    _buildOneColumnLayout(
                      colors,
                      typography,
                      l10n,
                      isDark,
                    ),
                ],
              ),
      ),
    );
  }

  /// Ambient background glowing orbs that gently breathe to provide subtle depth
  Widget _buildAmbientBackgroundOrbs(
    AppThemeColorsExtension colors,
    bool isDark,
    bool isLandscape,
  ) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -60,
              left: isLandscape ? 40 : -40,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.primary.withAlpha(isDark ? 40 : 25),
                      colors.syllabotAccent.withAlpha(isDark ? 25 : 12),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.15, 1.15),
                    duration: 3800.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
            Positioned(
              bottom: 40,
              right: isLandscape ? 40 : -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.syllabotAccent.withAlpha(isDark ? 30 : 18),
                      colors.primary.withAlpha(isDark ? 20 : 10),
                      Colors.transparent,
                    ],
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1.1, 1.1),
                    end: const Offset(0.85, 0.85),
                    duration: 4200.ms,
                    curve: Curves.easeInOut,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Two-column layout for landscape smartphones, tablets, and desktop/web.
  /// Delivers a unified, elevated dual-stage experience without split-scroll jank.
  Widget _buildTwoColumnLayout(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
    Size size,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1140),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Hero Value Proposition Showcase Card
              Expanded(
                flex: 6,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(160)
                        : colors.surfacePrimary.withAlpha(220),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 55 : 35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 65 : 15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroHeader(colors, typography, l10n, isDark),
                      const SizedBox(height: 16),
                      _buildSocialProofStrip(colors, typography, l10n, isDark),
                      const SizedBox(height: 20),
                      _buildFeatureMatrix(colors, typography, l10n, isDark),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 20),

              // Right Column: Premium Checkout Engine & Plan Selector Card
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary.withAlpha(190)
                        : colors.surfacePrimary.withAlpha(240),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 90 : 60),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 35 : 15),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTierPlansSelector(colors, typography, l10n, isDark),
                      const SizedBox(height: 16),
                      _buildTransparentTimeline(colors, typography, l10n, isDark),
                      const SizedBox(height: 18),
                      _buildCheckoutControls(
                        colors: colors,
                        typography: typography,
                        l10n: l10n,
                        isDark: isDark,
                        isInline: true,
                      ),
                      const SizedBox(height: 16),
                      _buildFooter(colors, typography, l10n),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Single-column scroll layout for compact mobile portrait devices
  Widget _buildOneColumnLayout(
    AppThemeColorsExtension colors,
    TypographyThemeExtension typography,
    AppLocalizations l10n,
    bool isDark,
  ) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeroHeader(colors, typography, l10n, isDark),
              const SizedBox(height: 14),
              _buildSocialProofStrip(colors, typography, l10n, isDark),
              const SizedBox(height: 16),
              _buildTierPlansSelector(colors, typography, l10n, isDark),
              const SizedBox(height: 14),
              _buildTransparentTimeline(colors, typography, l10n, isDark),
              const SizedBox(height: 16),
              _buildFeatureMatrix(colors, typography, l10n, isDark),
              const SizedBox(height: 16),
              _buildFooter(colors, typography, l10n),
              const SizedBox(height: 24),
            ]
                .animate(interval: 60.ms)
                .fadeIn(
                  duration: 280.ms,
                  curve: Curves.easeOutCubic,
                )
                .slideY(
                  begin: 0.04,
                  end: 0,
                  duration: 280.ms,
                  curve: Curves.easeOutCubic,
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
        // Scholar Badge with continuous light-sweep shimmer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withAlpha(90),
                colors.syllabotAccent.withAlpha(70),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colors.primary.withAlpha(150),
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
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                l10n.paywallScholarBadge,
                style: typography.caption.bold.copyWith(
                  color: colors.white,
                  fontSize: 11,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              delay: 1200.ms,
              duration: 2200.ms,
              color: colors.white.withAlpha(70),
              angle: 45,
            ),
        const SizedBox(height: 10),
        Text(
          l10n.paywallHeroTitle,
          textAlign: TextAlign.center,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.paywallHeroSubtitle,
          textAlign: TextAlign.center,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 12.5,
            height: 1.35,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            height: 16,
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
        Icon(icon, color: iconColor, size: 15)
            .animate()
            .scale(
              begin: const Offset(0.7, 0.7),
              end: const Offset(1, 1),
              duration: 350.ms,
              curve: Curves.easeOutBack,
            ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: typography.footnote.bold.copyWith(
              color: colors.textPrimary,
              fontSize: 10.5,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        color: colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 65 : 45)
                              : (isHovered ? 35 : 20),
                        ),
                        blurRadius: isHovered ? 18 : 14,
                        offset: Offset(0, isHovered ? 5 : 3),
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
                    AnimatedScale(
                      scale: isSelected ? 1.08 : 1.0,
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? colors.primary : colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
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
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Pulsing "SAVE 45%" Badge
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
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.success.withAlpha(60),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  l10n.paywallAnnualSaveBadge,
                                  style: typography.caption.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 9,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              )
                                  .animate(
                                    onPlay: (controller) =>
                                        controller.repeat(reverse: true),
                                  )
                                  .scale(
                                    begin: const Offset(1, 1),
                                    end: const Offset(1.06, 1.06),
                                    duration: 1400.ms,
                                    curve: Curves.easeInOut,
                                  ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.paywallAnnualPlanSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.paywallAnnualWeeklyNote,
                            style: typography.footnote.medium.copyWith(
                              color: colors.primary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              l10n.paywallPerMonth,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          r'$8.99/mo',
                          style: typography.footnote.regular.copyWith(
                            color: colors.textSecondary.withAlpha(120),
                            decoration: TextDecoration.lineThrough,
                            fontSize: 10.5,
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
        const SizedBox(height: 8),

        // Monthly Plan Card
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            final isSelected = _selectedPlanIndex == 1;
            return ShrinkableButton(
              onTap: () => _selectPlan(1),
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        color: colors.primary.withAlpha(
                          isDark
                              ? (isHovered ? 60 : 40)
                              : (isHovered ? 30 : 15),
                        ),
                        blurRadius: isHovered ? 18 : 14,
                        offset: Offset(0, isHovered ? 5 : 3),
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
                    AnimatedScale(
                      scale: isSelected ? 1.08 : 1.0,
                      duration: AppMotion.snappy,
                      curve: Curves.easeOutBack,
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected ? colors.primary : colors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.paywallMonthlyPlanTitle,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.paywallMonthlyPlanSubtitle,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                            fontSize: 17,
                          ),
                        ),
                        Text(
                          l10n.paywallPerMonth,
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 10.5,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(35),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: typography.footnote.bold.copyWith(
                  color: colors.primary,
                  fontSize: 9,
                ),
              ),
            ),
          )
              .animate()
              .scale(
                begin: const Offset(0.7, 0.7),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 9.5,
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
      borderRadius: AppRadius.radiusPanel,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(200)
                : colors.surfacePrimary.withAlpha(220),
            borderRadius: AppRadius.radiusPanel,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(isDark ? 90 : 60),
            ),
          ),
          child: Column(
            children: features
                .asMap()
                .entries
                .map(
                  (entry) {
                    final f = entry.value;
                    return PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        return AnimatedContainer(
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isHovered
                                ? colors.primary.withAlpha(isDark ? 30 : 18)
                                : Colors.transparent,
                            borderRadius: AppRadius.radiusPanel,
                            border: Border.all(
                              color: isHovered
                                  ? colors.primary.withAlpha(90)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(35),
                                  borderRadius: AppRadius.radiusCard,
                                ),
                                child: Icon(
                                  f.icon,
                                  color: colors.primary,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.title,
                                      style: typography.body.bold.copyWith(
                                        color: colors.textPrimary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      f.subtitle,
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                        fontSize: 11,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.check_circle_rounded,
                                color: colors.success,
                                size: 18,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                )
                .toList()
                .animate(interval: 50.ms)
                .fadeIn(duration: 350.ms, curve: Curves.easeOutCubic)
                .slideX(
                  begin: 0.04,
                  end: 0,
                  duration: 350.ms,
                  curve: Curves.easeOutCubic,
                ),
          ),
        ),
      ),
    );
  }

  /// Pinned bottom action bar containing the primary CTA, guarantee, and promo code entry for 1-column mobile portrait.
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildCheckoutControls(
            colors: colors,
            typography: typography,
            l10n: l10n,
            isDark: isDark,
            isInline: false,
          ),
        ),
      ),
    );
  }

  /// Unified Checkout Controls (CTA button, guarantee, promo code button)
  /// Used both pinned at the bottom in portrait and inline in 2-column landscape/desktop.
  Widget _buildCheckoutControls({
    required AppThemeColorsExtension colors,
    required TypographyThemeExtension typography,
    required AppLocalizations l10n,
    required bool isDark,
    required bool isInline,
  }) {
    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: typography.caption.medium.copyWith(
              color: colors.error,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Primary Purchase CTA with continuous shimmering light-sweep effect
        PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return ShrinkableButton(
              onTap: _isProcessing ? null : _handlePurchase,
              child: AnimatedContainer(
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
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
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_open_rounded,
                              color: colors.white,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l10n.paywallCtaButton,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.body.bold.copyWith(
                                  color: colors.white,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    delay: 1800.ms,
                    duration: 2000.ms,
                    color: colors.white.withAlpha(80),
                    angle: 35,
                  ),
            );
          },
        ),
        const SizedBox(height: 6),

        // Security Guarantee (Guaranteed overflow-free with Flexible and Ellipsis)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 12,
              color: colors.textSecondary.withAlpha(160),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                l10n.paywallSecurityGuarantee,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.footnote.medium.copyWith(
                  color: colors.textSecondary.withAlpha(170),
                  fontSize: 10.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Promo Code Redemption Action
        Center(
          child: PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return ShrinkableButton(
                onTap: _isProcessing ? null : _handlePromoCodeRedemption,
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? colors.primary.withAlpha(25)
                        : Colors.transparent,
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.card_giftcard_rounded,
                        size: 14,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        l10n.paywallHavePromoCode,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 12,
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
    );

    if (isInline) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(160)
              : colors.surfacePrimary.withAlpha(190),
          borderRadius: AppRadius.radiusPanel,
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(60),
          ),
        ),
        child: cardContent,
      );
    }

    return cardContent;
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
            fontSize: 10,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 8),
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
                  fontSize: 10.5,
                  decoration: TextDecoration.underline,
                  decorationColor: colors.primary.withAlpha(180),
                ),
              ),
            ),
            Text(
              '•',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary.withAlpha(120),
                fontSize: 10.5,
              ),
            ),
            GestureDetector(
              onTap: () => _launchUrl(PaywallScreen.termsOfServiceUrl),
              child: Text(
                l10n.termsOfService,
                style: typography.caption.medium.copyWith(
                  color: colors.primary,
                  fontSize: 10.5,
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
