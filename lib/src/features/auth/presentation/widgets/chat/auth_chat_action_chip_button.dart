import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Reusable glassmorphic action chip button used in the conversational AI chat authentication flow.
class AuthChatActionChipButton extends StatelessWidget {
  const AuthChatActionChipButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = false,
    this.isFullWidth = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: 'Action: $label',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onTap();
            },
            child: ClipRRect(
              borderRadius: AppRadius.radiusPanel,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.radiusPanel,
                    color: isPrimary
                        ? (isHovered
                              ? colors.primary
                              : colors.primary.withAlpha(isDark ? 220 : 240))
                        : (isHovered
                              ? (isDark
                                    ? colors.surfaceSecondary.withAlpha(220)
                                    : colors.surfacePrimary)
                              : (isDark
                                    ? colors.surfaceSecondary.withAlpha(170)
                                    : colors.surfacePrimary.withAlpha(220))),
                    border: Border.all(
                      color: isPrimary
                          ? (isHovered
                                ? colors.white.withAlpha(80)
                                : colors.primary)
                          : (isHovered
                                ? colors.primary.withAlpha(150)
                                : (isDark
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          80,
                                        )
                                      : colors.surfaceBorder.withAlpha(140))),
                      width: isHovered && !isPrimary ? 1.4 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark
                              ? (isHovered ? 70 : 40)
                              : (isHovered ? 25 : 10),
                        ),
                        blurRadius: isHovered ? 12 : 8,
                        offset: Offset(0, isHovered ? 3 : 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 16,
                          color: isPrimary ? colors.white : colors.primary,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.caption.semiBold.copyWith(
                            color: isPrimary
                                ? colors.white
                                : colors.textPrimary,
                            fontSize: 13.5,
                          ),
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
    );
  }
}
