import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Outer modal shell providing frosted glass backdrops on desktop
/// and adaptive safe area handling on mobile.
class VoiceDialogueModalShell extends StatelessWidget {
  const VoiceDialogueModalShell({
    required this.isDesktop,
    required this.constraints,
    required this.stateColor,
    required this.onCloseModal,
    required this.child,
    super.key,
  });

  final bool isDesktop;
  final BoxConstraints constraints;
  final Color stateColor;
  final VoidCallback onCloseModal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final contentWithAura = Stack(
      children: [
        // Subtle Ambient Radial Aura behind the Ribbon
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.snappyCurve,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.15),
                  radius: 0.75,
                  colors: [
                    stateColor.withValues(alpha: isDark ? 0.18 : 0.09),
                    colors.backgroundPrimary.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Primary Content Layout
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 20,
            vertical: isDesktop ? 16 : 8,
          ),
          child: child,
        ),
      ],
    );

    if (isDesktop) {
      return Stack(
        children: [
          // Frosted Ambient Backdrop
          GestureDetector(
            onTap: onCloseModal,
            behavior: HitTestBehavior.opaque,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
          // Centered Elevated Glass Shell
          Center(
            child: Container(
              width: math.min(constraints.maxWidth - 48, 680),
              height: math.min(constraints.maxHeight * 0.88, 800),
              constraints: const BoxConstraints(minHeight: 520),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: colors.surfaceBorder.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 40,
                    spreadRadius: 4,
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: stateColor.withValues(alpha: 0.12),
                    blurRadius: 60,
                    spreadRadius: -10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SafeArea(
                  child: contentWithAura,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Mobile / Adaptive Sheet Presentation with Strict Safe Area Insets
    final mediaQuery = MediaQuery.of(context);
    final windowTopPadding =
        View.of(context).padding.top / View.of(context).devicePixelRatio;
    final topInset = math.max(
      mediaQuery.viewPadding.top,
      math.max(mediaQuery.padding.top, windowTopPadding),
    );

    final windowBottomPadding =
        View.of(context).padding.bottom / View.of(context).devicePixelRatio;
    final bottomInset = math.max(
      mediaQuery.viewPadding.bottom,
      math.max(mediaQuery.padding.bottom, windowBottomPadding),
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.dialog),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: topInset > 0 ? topInset + 6 : 12,
          bottom: bottomInset > 0 ? bottomInset + 4 : 12,
        ),
        child: contentWithAura,
      ),
    );
  }
}
