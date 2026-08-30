import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';

/// Translucent top bar with Kortex SVG logo and accessible Skip CTA.
class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({
    required this.isLastPage,
    required this.onSkip,
    super.key,
  });

  final bool isLastPage;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surfacePrimary.withAlpha(isDark ? 160 : 200),
            border: Border(
              bottom: BorderSide(
                color: colors.surfaceBorder.withAlpha(isDark ? 60 : 30),
                width: 0.8,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Kortex Brand Logo & Typography
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppAssets.svgs.kortexLogo.svg(
                    width: 22,
                    height: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.appName,
                    style: typography.caption.bold.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 13,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),

              // Skip CTA Button
              if (!isLastPage)
                Semantics(
                  button: true,
                  label: l10n.onboardingSkipSemantics,
                  child: TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: const Size(48, 36),
                    ),
                    child: Text(
                      l10n.onboardingSkip,
                      style: typography.subhead.semiBold.copyWith(
                        color: colors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }
}
