import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Hero header section with pulsing scholar badge and title/subtitle copy.
class PaywallHeroHeader extends StatelessWidget {
  const PaywallHeroHeader({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
}

/// Strip displaying social proof and educational efficacy metrics.
class PaywallSocialProofStrip extends StatelessWidget {
  const PaywallSocialProofStrip({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
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
            child: TrustBadge(
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
              child: TrustBadge(
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
}

class TrustBadge extends StatelessWidget {
  const TrustBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.colors,
    required this.typography,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
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
}
