import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_checkout_dock.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_features_timeline_section.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_footer_links.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_hero_section.dart';
import 'package:kortex/src/features/monetization/presentation/widgets/paywall_tier_plans_selector.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Single-column plan offering content with hero, plans selector, timeline, features, and footer.
class PaywallPlanContent extends StatelessWidget {
  const PaywallPlanContent({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    required this.selectedPlanIndex,
    required this.onSelectPlan,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTermsOfService,
    this.offerings,
    this.isInlineCheckout = false,
    this.isProcessing = false,
    this.errorMessage,
    this.onPurchase,
    this.onPromoCode,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final int selectedPlanIndex;
  final ValueChanged<int> onSelectPlan;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTermsOfService;
  final Offerings? offerings;
  final bool isInlineCheckout;
  final bool isProcessing;
  final String? errorMessage;
  final VoidCallback? onPurchase;
  final VoidCallback? onPromoCode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PaywallHeroHeader(
                colors: colors,
                typography: typography,
                l10n: l10n,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              PaywallSocialProofStrip(
                colors: colors,
                typography: typography,
                l10n: l10n,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              PaywallTierPlansSelector(
                selectedPlanIndex: selectedPlanIndex,
                onSelectPlan: onSelectPlan,
                colors: colors,
                typography: typography,
                l10n: l10n,
                isDark: isDark,
                offerings: offerings,
              ),
              const SizedBox(height: 14),
              PaywallTransparentTimeline(
                colors: colors,
                typography: typography,
                l10n: l10n,
                isDark: isDark,
              ),
              if (isInlineCheckout && onPurchase != null && onPromoCode != null) ...[
                const SizedBox(height: 16),
                PaywallCheckoutControls(
                  colors: colors,
                  typography: typography,
                  l10n: l10n,
                  isDark: isDark,
                  isInline: true,
                  isProcessing: isProcessing,
                  errorMessage: errorMessage,
                  onPurchase: onPurchase!,
                  onPromoCode: onPromoCode!,
                ),
              ],
              const SizedBox(height: 18),
              PaywallFeatureMatrix(
                colors: colors,
                typography: typography,
                l10n: l10n,
                isDark: isDark,
              ),
              const SizedBox(height: 16),
              PaywallFooter(
                colors: colors,
                typography: typography,
                l10n: l10n,
                onOpenPrivacyPolicy: onOpenPrivacyPolicy,
                onOpenTermsOfService: onOpenTermsOfService,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
