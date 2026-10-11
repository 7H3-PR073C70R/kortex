import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

class ProFeatureItem {
  const ProFeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

/// Transparent 3-step timeline clarifying billing cycle and cancellation terms.
class PaywallTransparentTimeline extends StatelessWidget {
  const PaywallTransparentTimeline({
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
}

/// Feature Matrix showing unlocked Pro powers with glassmorphic cards and hover feedback.
class PaywallFeatureMatrix extends StatelessWidget {
  const PaywallFeatureMatrix({
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
    final features = [
      ProFeatureItem(
        icon: Icons.psychology_rounded,
        title: l10n.paywallFeature1Title,
        subtitle: l10n.paywallFeature1Subtitle,
      ),
      ProFeatureItem(
        icon: Icons.document_scanner_rounded,
        title: l10n.paywallFeature2Title,
        subtitle: l10n.paywallFeature2Subtitle,
      ),
      ProFeatureItem(
        icon: Icons.auto_mode_rounded,
        title: l10n.paywallFeature3Title,
        subtitle: l10n.paywallFeature3Subtitle,
      ),
      ProFeatureItem(
        icon: Icons.cloud_sync_rounded,
        title: l10n.paywallFeature4Title,
        subtitle: l10n.paywallFeature4Subtitle,
      ),
      ProFeatureItem(
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
}
