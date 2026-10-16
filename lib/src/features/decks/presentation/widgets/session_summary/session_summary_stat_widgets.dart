import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';

/// Scale-in entrance for the orb; skipped entirely under reduced motion.
class OrbEntrance extends StatelessWidget {
  const OrbEntrance({
    required this.reduceMotion,
    required this.child,
    super.key,
  });

  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutQuint,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
      ),
      child: child,
    );
  }
}

/// Stat display item with optional animated counting up to [countTo].
class SessionStatItem extends StatelessWidget {
  const SessionStatItem({
    required this.label,
    required this.color,
    required this.colors,
    required this.reduceMotion,
    required this.staggerIndex,
    this.countTo,
    this.format,
    this.display,
    super.key,
  }) : assert(
         (countTo != null) == (format != null),
         'countTo and format must be provided together',
       ),
       assert(
         countTo != null || display != null,
         'provide either countTo or display',
       );

  final String label;
  final Color color;
  final AppThemeColorsExtension colors;
  final bool reduceMotion;
  final int staggerIndex;

  /// When set, the value animates 0 -> [countTo] through [format].
  final int? countTo;
  final String Function(int value)? format;

  /// Static value for stats that should not count up (e.g. mm:ss time).
  final String? display;

  static const _tabular = [FontFeature.tabularFigures()];

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final countTarget = countTo;

    final valueText = display ?? '$countTo';

    return StaggeredFade(
      reduceMotion: reduceMotion,
      staggerIndex: staggerIndex,
      child: Column(
        children: [
          if (countTarget != null && !reduceMotion)
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: countTarget),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuint,
              builder: (context, value, _) => Text(
                format!(value),
                style: typography.title3.bold.copyWith(
                  color: color,
                  fontSize: 20,
                  fontFeatures: _tabular,
                ),
              ),
            )
          else
            Text(
              valueText,
              style: typography.title3.bold.copyWith(
                color: color,
                fontSize: 20,
                fontFeatures: _tabular,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: typography.footnote.regular.copyWith(
              color: colors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft fade-in offset per stat so the three numbers don't land at once.
class StaggeredFade extends StatelessWidget {
  const StaggeredFade({
    required this.reduceMotion,
    required this.staggerIndex,
    required this.child,
    super.key,
  });

  final bool reduceMotion;
  final int staggerIndex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 250 + staggerIndex * 100),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: child,
    );
  }
}
