import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

/// Overlay badge displaying the intended rating / action during card drag gesture.
class CardDragRouteIndicator extends StatelessWidget {
  const CardDragRouteIndicator({
    required this.routeColor,
    required this.routeLabel,
    required this.routeIcon,
    required this.dragProgress,
    super.key,
  });

  final Color routeColor;
  final String routeLabel;
  final IconData routeIcon;
  final double dragProgress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Positioned(
      top: 24,
      child: Opacity(
        opacity: dragProgress,
        child: Transform.scale(
          scale: 0.85 + (0.25 * dragProgress),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: routeColor.withAlpha(isDark ? 230 : 255),
              borderRadius: BorderRadius.circular(AppRadius.dialog),
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(isDark ? 60 : 30),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(routeIcon, color: colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  routeLabel,
                  style: typography.caption.bold.copyWith(
                    color: colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
