import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/gen/assets.gen.dart';

/// Production-ready animated brand loader widget.
///
/// Features a breathing Kortex hexagon logo surrounded by a rotating
/// multi-stop gradient halo with accessible reduced-motion support.
class AppLogoLoader extends StatefulWidget {
  const AppLogoLoader({
    super.key,
    this.size = 64,
    this.message,
    this.showMessage = true,
    this.color,
  });

  final double size;
  final String? message;
  final bool showMessage;
  final Color? color;

  @override
  State<AppLogoLoader> createState() => _AppLogoLoaderState();
}

class _AppLogoLoaderState extends State<AppLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    final logoSize = widget.size * 0.56;
    final haloPrimary = widget.color ?? colors.primary;
    final haloAccent = widget.color ?? colors.syllabotAccent;
    final inset = widget.size < 32
        ? (widget.size * 0.12).clamp(1.5, 3.0)
        : 6.0;
    final innerSize = math.max(4.0, widget.size - (inset * 2));
    final blurRadius = (widget.size * 0.25).clamp(2.0, 16.0);
    final spreadRadius = widget.size > 32 ? 2.0 : 0.5;

    return Semantics(
      label: widget.message ?? 'Loading, please wait...',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final angle = disableAnimations
                    ? 0.0
                    : _controller.value * 2 * math.pi;
                final scale = disableAnimations
                    ? 1.0
                    : 0.94 + 0.06 * math.sin(_controller.value * 2 * math.pi);

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating glowing gradient aura
                    Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              haloPrimary.withAlpha(0),
                              haloPrimary.withAlpha(isDark ? 140 : 100),
                              haloAccent.withAlpha(isDark ? 220 : 180),
                              haloPrimary,
                            ],
                            stops: const [0.0, 0.45, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Inner frosted background disc
                    Container(
                      width: innerSize,
                      height: innerSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark
                            ? colors.backgroundPrimary
                            : colors.surfacePrimary,
                        boxShadow: [
                          BoxShadow(
                            color: haloPrimary.withAlpha(
                              isDark ? 60 : 30,
                            ),
                            blurRadius: blurRadius,
                            spreadRadius: spreadRadius,
                          ),
                        ],
                      ),
                    ),

                    // Centered Breathing Kortex Logo
                    Transform.scale(
                      scale: scale,
                      child: AppAssets.svgs.kortexLogo.svg(
                        width: logoSize,
                        height: logoSize,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (widget.showMessage && widget.message != null) ...[
            const SizedBox(height: 14),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: typography.footnote.medium.copyWith(
                color: colors.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
