import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Pinned bottom action bar containing the primary CTA, guarantee, and promo code entry for 1-column mobile portrait.
class PaywallStickyBottomDock extends StatelessWidget {
  const PaywallStickyBottomDock({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    required this.isProcessing,
    required this.onPurchase,
    required this.onPromoCode,
    this.errorMessage,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isProcessing;
  final VoidCallback onPurchase;
  final VoidCallback onPromoCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
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
          child: PaywallCheckoutControls(
            colors: colors,
            typography: typography,
            l10n: l10n,
            isDark: isDark,
            isInline: false,
            isProcessing: isProcessing,
            onPurchase: onPurchase,
            onPromoCode: onPromoCode,
            errorMessage: errorMessage,
          ),
        ),
      ),
    );
  }
}

/// Unified Checkout Controls (CTA button, guarantee, promo code button).
/// Used both pinned at the bottom in portrait and inline in 2-column landscape/desktop.
class PaywallCheckoutControls extends StatelessWidget {
  const PaywallCheckoutControls({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    required this.isInline,
    required this.isProcessing,
    required this.onPurchase,
    required this.onPromoCode,
    this.errorMessage,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isInline;
  final bool isProcessing;
  final VoidCallback onPurchase;
  final VoidCallback onPromoCode;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final cardContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorMessage != null) ...[
          Text(
            errorMessage!,
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
              onTap: isProcessing ? null : onPurchase,
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
                  child: isProcessing
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

        // Security Guarantee
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
                onTap: isProcessing ? null : onPromoCode,
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
}
