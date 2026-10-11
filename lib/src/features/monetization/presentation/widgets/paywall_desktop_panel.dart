import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';

/// Sliding right drawer container for wide screen and slide-overlay display.
class PaywallDesktopPanel extends StatelessWidget {
  const PaywallDesktopPanel({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    required this.isPro,
    required this.panelWidth,
    required this.child,
    required this.onDismiss,
    required this.onRestore,
    this.isProcessing = false,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isPro;
  final double panelWidth;
  final Widget child;
  final VoidCallback onDismiss;
  final VoidCallback onRestore;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SizedBox.expand(
        child: Stack(
            children: [
            // Dismissible dark backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: onDismiss,
                child: Container(
                  color: colors.black.withAlpha(isDark ? 160 : 100),
                ),
              ),
            ),

            // Sliding Right Drawer Panel
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: panelWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  boxShadow: [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 160 : 70),
                      blurRadius: 32,
                      offset: const Offset(-8, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PaywallDesktopPanelHeader(
                        colors: colors,
                        typography: typography,
                        l10n: l10n,
                        isDark: isDark,
                        isPro: isPro,
                        isProcessing: isProcessing,
                        onDismiss: onDismiss,
                        onRestore: onRestore,
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: colors.surfaceBorder.withAlpha(isDark ? 50 : 80),
                      ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              )
                  .animate()
                  .slideX(
                    begin: 1,
                    end: 0,
                    duration: 300.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeIn(duration: 180.ms),
            ),
          ],
        ),
      ),
    );
  }
}

class PaywallDesktopPanelHeader extends StatelessWidget {
  const PaywallDesktopPanelHeader({
    required this.colors,
    required this.typography,
    required this.l10n,
    required this.isDark,
    required this.isPro,
    required this.onDismiss,
    required this.onRestore,
    this.isProcessing = false,
    super.key,
  });

  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final AppLocalizations l10n;
  final bool isDark;
  final bool isPro;
  final VoidCallback onDismiss;
  final VoidCallback onRestore;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          PlatformHoverBuilder(
            builder: (context, isHovered, child) {
              return IconButton(
                icon: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isHovered
                        ? (isDark
                              ? colors.surfaceSecondary
                              : colors.surfacePrimary)
                        : (isDark
                              ? colors.surfaceSecondary.withAlpha(180)
                              : colors.surfacePrimary.withAlpha(200)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isHovered
                          ? colors.primary.withAlpha(120)
                          : colors.surfaceBorder.withAlpha(80),
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: isHovered ? colors.primary : colors.textPrimary,
                    size: 18,
                  ),
                ),
                onPressed: onDismiss,
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            'Kortexify Pro',
            style: typography.title3.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const Spacer(),
          if (!kIsWeb && !isPro)
            TextButton(
              onPressed: isProcessing ? null : onRestore,
              child: Text(
                l10n.paywallRestore,
                style: typography.callout.bold.copyWith(
                  color: colors.primary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
