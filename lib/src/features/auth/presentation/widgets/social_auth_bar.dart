import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Floating social authentication triggers for instant Google
/// and Apple sign-in with WCAG 2.1 AA compliant semantics and glassmorphism.
class SocialAuthBar extends StatelessWidget {
  const SocialAuthBar({
    required this.onGooglePressed,
    required this.onApplePressed,
    super.key,
    this.isLoading = false,
  });

  final VoidCallback onGooglePressed;
  final VoidCallback onApplePressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        // Google Sign In
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.authSocialGoogleSemantics,
            hint: l10n.authSocialGoogleHint,
            child: PlatformHoverBuilder(
              isEnabled: !isLoading,
              builder: (context, isHovered, child) {
                return ShrinkableButton(
                  onTap: isLoading
                      ? null
                      : () {
                          unawaited(HapticFeedback.lightImpact());
                          onGooglePressed();
                        },
                  child: ClipRRect(
                    borderRadius: AppRadius.radiusPanel,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.radiusPanel,
                          color: isHovered
                              ? (isDark
                                    ? colors.surfaceSecondary.withAlpha(220)
                                    : colors.surfacePrimary)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(180)
                                    : colors.surfacePrimary.withAlpha(200)),
                          border: Border.all(
                            color: isHovered
                                ? colors.primary.withAlpha(isDark ? 140 : 100)
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          90,
                                        )
                                      : colors.surfaceBorder.withAlpha(140)),
                            width: isHovered ? 1.4 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(
                                isDark
                                    ? (isHovered ? 80 : 60)
                                    : (isHovered ? 25 : 15),
                              ),
                              blurRadius: isHovered ? 14 : 10,
                              offset: Offset(0, isHovered ? 4 : 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.g_mobiledata_rounded,
                              size: 24,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.authSocialGoogleLabel,
                              style: typography.subhead.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Apple ID Sign In
        Expanded(
          child: Semantics(
            button: true,
            label: l10n.authSocialAppleSemantics,
            hint: l10n.authSocialAppleHint,
            child: PlatformHoverBuilder(
              isEnabled: !isLoading,
              builder: (context, isHovered, child) {
                return ShrinkableButton(
                  onTap: isLoading
                      ? null
                      : () {
                          unawaited(HapticFeedback.lightImpact());
                          onApplePressed();
                        },
                  child: ClipRRect(
                    borderRadius: AppRadius.radiusPanel,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.radiusPanel,
                          color: isHovered
                              ? (isDark
                                    ? colors.surfaceSecondary.withAlpha(220)
                                    : colors.surfacePrimary)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(180)
                                    : colors.surfacePrimary.withAlpha(200)),
                          border: Border.all(
                            color: isHovered
                                ? colors.textPrimary.withAlpha(
                                    isDark ? 100 : 70,
                                  )
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          90,
                                        )
                                      : colors.surfaceBorder.withAlpha(140)),
                            width: isHovered ? 1.4 : 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(
                                isDark
                                    ? (isHovered ? 80 : 60)
                                    : (isHovered ? 25 : 15),
                              ),
                              blurRadius: isHovered ? 14 : 10,
                              offset: Offset(0, isHovered ? 4 : 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.apple,
                              size: 20,
                              color: colors.textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n.authSocialAppleLabel,
                              style: typography.subhead.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
