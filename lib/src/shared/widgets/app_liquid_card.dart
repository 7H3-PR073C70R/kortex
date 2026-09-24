import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Platform-adaptive card that renders a liquid glass surface with specular
/// refraction and blur on Apple platforms (iOS/macOS), and a clean Material 3
/// surface container on Android and other platforms.
class AppLiquidCard extends StatelessWidget {
  const AppLiquidCard({
    required this.child,
    super.key,
    this.padding,
    this.borderRadius,
    this.settings,
  });

  /// The widget content rendered within this card.
  final Widget child;

  /// Optional inner padding.
  final EdgeInsetsGeometry? padding;

  /// Card corner radius. Defaults to [AppRadius.card] if not specified.
  final double? borderRadius;

  /// Custom liquid glass settings on Apple platforms.
  final LiquidGlassSettings? settings;

  bool get _isApplePlatform {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final radius = borderRadius ?? AppRadius.card;

    if (_isApplePlatform) {
      final effectiveSettings = settings ??
          LiquidGlassSettings(
            blur: 20,
            glassColor: isDark
                ? colors.surfaceSecondary.withAlpha(70)
                : colors.white.withAlpha(170),
            lightIntensity: isDark ? 0.35 : 0.8,
            refractiveIndex: 1.25,
          );

      return GlassCard(
        settings: effectiveSettings,
        shape: LiquidRoundedSuperellipse(
          borderRadius: radius,
        ),
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      );
    }

    // Material 3 capsule surface container on Android / desktop / web
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(235)
            : colors.surfacePrimary.withAlpha(245),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(60)
              : colors.surfaceBorder.withAlpha(140),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
