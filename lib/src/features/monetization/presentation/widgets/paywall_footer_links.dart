import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Paywall footer with auto-renewal disclosure, Privacy Policy, and Terms of Service links.
class PaywallFooter extends StatelessWidget {
  const PaywallFooter({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.onOpenPrivacyPolicy,
    required this.onOpenTermsOfService,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final VoidCallback onOpenPrivacyPolicy;
  final VoidCallback onOpenTermsOfService;

  @override
  Widget build(BuildContext context) {
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
              onTap: onOpenPrivacyPolicy,
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
              onTap: onOpenTermsOfService,
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
