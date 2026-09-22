import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';
import 'package:kortex/src/l10n/l10n.dart';

// -----------------------------------------------------------------------------
// A shared presentation layer for the auth flow.
//
// The auth screens previously re-derived their own glass, blur, shadow and
// entrance behaviour in five different places, so the flow felt assembled
// rather than designed. These primitives give the whole flow one surface
// language and one signature entrance, the two things users subconsciously
// read as "this product is crafted".
// -----------------------------------------------------------------------------

/// One-shot entrance used across the auth flow.
///
/// Fades + rises a child into place with the brand's ease-out curve. The
/// [delayMs] is expressed as an [Interval] on a single [AnimationController]
/// (not a delayed future or timer), so it can never leave a pending timer
/// behind in widget tests and stays cheap on device.
class RevealOnMount extends StatefulWidget {
  const RevealOnMount({
    required this.child,
    this.delayMs = 0,
    this.durationMs = 440,
    this.slideY = 0.05,
    super.key,
  });

  final Widget child;

  /// How long the child waits (in ms) before it starts moving. Stagger by
  /// increasing this across sibling blocks to choreograph an entrance.
  final int delayMs;

  final int durationMs;

  /// Starting vertical offset as a fraction of the child's own height.
  final double slideY;

  @override
  State<RevealOnMount> createState() => _RevealOnMountState();
}

class _RevealOnMountState extends State<RevealOnMount>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final total = widget.delayMs + widget.durationMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );

    final begin = widget.delayMs / total;
    final curve = Interval(
      begin,
      1,
      curve: AppMotion.easeOutCubic,
    );
    _fade = CurvedAnimation(parent: _controller, curve: curve);
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideY),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: curve));

    unawaited(_controller.forward());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// The Kortexify brand lockup: a gradient logo tile paired with the wordmark.
///
/// Renders [AppLocalizations.appName] exactly once (the auth tests assert a
/// single 'KORTEXIFY' on screen), so keep any tagline text distinct from it.
class AuthBrandLockup extends StatelessWidget {
  const AuthBrandLockup({
    this.size = BrandLockupSize.regular,
    this.onLightSurface = false,
    super.key,
  });

  final BrandLockupSize size;

  /// Set true when the lockup sits on a dark hero (white wordmark).
  final bool onLightSurface;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    final logo = size == BrandLockupSize.large ? 30.0 : 26.0;
    final wordmark = size == BrandLockupSize.large ? 17.0 : 14.5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo sits directly on the canvas — no avatar/tile behind it.
        AppAssets.svgs.kortexLogo.svg(width: logo, height: logo),
        SizedBox(width: size == BrandLockupSize.large ? 12 : 10),
        Text(
          l10n.appName,
          style: typography.caption.bold.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            fontSize: wordmark,
            color: onLightSurface ? colors.white : colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

enum BrandLockupSize { regular, large }

/// Unified frosted-glass surface for the auth flow.
///
/// Centralises blur, fill, border and elevation so the form card and any new
/// panel read as the same material. Callers supply only [child] and optional
/// [padding]; everything else is a shared token.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.blur = AuthGlass.blur,
    this.radius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double blur;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final effectiveRadius = radius ?? AuthGlass.radius;

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: AuthGlass.decoration(
            colors: colors,
            isDark: isDark,
            radius: effectiveRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shared glass tokens for the auth flow's surfaces.
class AuthGlass {
  const AuthGlass._();

  static const double blur = 18;
  static BorderRadius radius = AppRadius.radiusDialog;

  static BoxDecoration decoration({
    required AppThemeColorsExtension colors,
    required bool isDark,
    BorderRadius? radius,
  }) {
    return BoxDecoration(
      borderRadius: radius ?? AuthGlass.radius,
      color: isDark
          ? colors.surfaceSecondary.withAlpha(168)
          : colors.surfacePrimary.withAlpha(214),
      border: Border.all(
        color: isDark
            ? colors.surfaceBorderHighlight.withAlpha(80)
            : colors.surfaceBorder.withAlpha(150),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: colors.black.withAlpha(isDark ? 60 : 18),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
