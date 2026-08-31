import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Stationary top bar featuring Kortex Logo and translucent "Skip" button.
class ContentTopBar extends StatelessWidget {
  const ContentTopBar({
    required this.onSkip,
    super.key,
  });

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Kortex Brand Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                AppAssets.svgs.kortexLogo.path,
                height: 24,
                width: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'KORTEX',
                style: typography.callout.bold.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Translucent Glass "Skip" Button
          Semantics(
            button: true,
            label: l10n.contentSkipButton,
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                onSkip();
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: isDark
                          ? colors.surfaceSecondary.withAlpha(120)
                          : colors.surfacePrimary.withAlpha(190),
                      border: Border.all(
                        color: isDark
                            ? colors.surfaceBorderHighlight.withAlpha(70)
                            : colors.surfaceBorder,
                      ),
                    ),
                    child: Text(
                      l10n.onboardingSkip,
                      style: typography.callout.bold.copyWith(
                        color: colors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
