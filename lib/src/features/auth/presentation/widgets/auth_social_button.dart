import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
    this.semanticsHint,
    super.key,
  });

  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final bool isLoading;
  final String? semanticsHint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      label: label,
      hint: semanticsHint,
      button: true,
      enabled: !isLoading,
      child: PlatformHoverBuilder(
        isEnabled: !isLoading,
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: isLoading
                ? null
                : () {
                    unawaited(HapticFeedback.lightImpact());
                    onTap();
                  },
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: isHovered
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(220)
                          : colors.surfacePrimary)
                    : (isDark
                          ? colors.surfaceSecondary
                          : colors.surfacePrimary),
                borderRadius: AppRadius.radiusPanel,
                border: Border.all(
                  color: isHovered
                      ? colors.primary.withAlpha(isDark ? 140 : 100)
                      : colors.primary.withAlpha(isDark ? 40 : 25),
                  width: isHovered ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(
                      isDark ? (isHovered ? 70 : 40) : (isHovered ? 25 : 10),
                    ),
                    blurRadius: isHovered ? 14 : 8,
                    offset: Offset(0, isHovered ? 4 : 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLoading)
                    AppLogoLoader(
                      size: 20,
                      color: colors.primary,
                    )
                  else ...[
                    icon,
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
