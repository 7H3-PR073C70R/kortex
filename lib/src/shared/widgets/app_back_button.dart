import 'dart:async';
import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// A reusable platform-aware back button that provides platform-adapted iconography
/// (iOS back chevron vs Material arrow back), subtle hover effects, haptic feedback,
/// and safe navigation pop logic.
class AppBackButton extends StatelessWidget {
  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 20.0,
    this.icon,
    this.semanticLabel,
    this.forceShow = false,
  });

  /// Custom callback on back tap. If null, automatically attempts `context.maybePop()`.
  final VoidCallback? onPressed;

  /// Custom icon color. Defaults to `colors.textPrimary`.
  final Color? color;

  /// Optional background fill color for header pill buttons.
  final Color? backgroundColor;

  /// Icon size. Defaults to 20.0.
  final double size;

  /// Optional custom icon override.
  final IconData? icon;

  /// Optional accessibility label. Defaults to localizations `backButton`.
  final String? semanticLabel;

  /// Whether to force the back button to display even on desktop/web wide layouts (>= 1024).
  /// Defaults to false.
  final bool forceShow;

  /// Breakpoint at which the desktop navigation rail is active and back buttons are hidden.
  static const double desktopBreakpoint = 1024;

  /// Returns true if back button should be visible on the current screen layout.
  static bool shouldShow(BuildContext context, {bool forceShow = false}) {
    if (forceShow) return true;
    return MediaQuery.sizeOf(context).width < desktopBreakpoint;
  }

  /// Convenience factory for AppBar leading widgets that returns null when wide,
  /// preventing AppBar from allocating leading width on wide layouts.
  static Widget? adaptiveLeading(
    BuildContext context, {
    Key? key,
    VoidCallback? onPressed,
    Color? color,
    Color? backgroundColor,
    double size = 20.0,
    IconData? icon,
    String? semanticLabel,
    bool forceShow = false,
  }) {
    if (!shouldShow(context, forceShow: forceShow)) return null;
    return AppBackButton(
      key: key,
      onPressed: onPressed,
      color: color,
      backgroundColor: backgroundColor,
      size: size,
      icon: icon,
      semanticLabel: semanticLabel,
      forceShow: forceShow,
    );
  }

  static bool get _isApplePlatform {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  IconData get _effectiveIcon {
    if (icon != null) return icon!;
    return _isApplePlatform
        ? Icons.arrow_back_ios_new_rounded
        : Icons.arrow_back_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (!shouldShow(context, forceShow: forceShow)) {
      return const SizedBox.shrink();
    }

    final colors = context.colors;
    final l10n = context.l10n;
    final effectiveColor = color ?? colors.textPrimary;
    final label = semanticLabel ?? l10n.backButton;
    final isDark = context.isDarkMode;

    return Semantics(
      button: true,
      label: label,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              if (onPressed != null) {
                onPressed!();
              } else {
                unawaited(context.maybePop());
              }
            },
            shrinkScale: 0.92,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: backgroundColor ??
                    (isHovered
                        ? colors.surfaceBorder.withAlpha(isDark ? 60 : 80)
                        : colors.transparent),
                borderRadius: BorderRadius.circular(AppRadius.badge),
              ),
              child: Icon(
                _effectiveIcon,
                color: effectiveColor,
                size: _isApplePlatform && icon == null ? (size - 2) : size,
              ),
            ),
          );
        },
      ),
    );
  }
}
