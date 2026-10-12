import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class DeckMarketplaceInlineCloneButton extends StatelessWidget {
  const DeckMarketplaceInlineCloneButton({
    required this.isCloning,
    required this.isAlreadyCloned,
    required this.onClone,
    super.key,
  });

  final bool isCloning;
  final bool isAlreadyCloned;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    if (isAlreadyCloned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: colors.recallEasy.withAlpha(isDark ? 40 : 25),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(
            color: colors.recallEasy.withAlpha(isDark ? 100 : 70),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: colors.recallEasy,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Deck in Library',
              style: typography.body.bold.copyWith(
                color: colors.recallEasy,
              ),
            ),
          ],
        ),
      );
    }

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.01 : 1,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: isCloning ? null : onClone,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCloning
                    ? [
                        colors.primary.withAlpha(160),
                        colors.primary.withAlpha(130),
                      ]
                    : [
                        colors.primary,
                        colors.primary.withAlpha(220),
                      ],
              ),
              borderRadius: AppRadius.radiusCard,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withAlpha(
                    isHovered ? 80 : 40,
                  ),
                  blurRadius: isHovered ? 16 : 8,
                  offset: Offset(0, isHovered ? 4 : 2),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: AppMotion.snappy,
              child: isCloning
                  ? AppLogoLoader(
                      key: const ValueKey('cloning_loader_inline'),
                      size: 18,
                      color: colors.white,
                      showMessage: false,
                    )
                  : Row(
                      key: const ValueKey('cloning_action_inline'),
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          color: colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.cloneDeckButton,
                          style: typography.body.bold.copyWith(
                            color: colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
