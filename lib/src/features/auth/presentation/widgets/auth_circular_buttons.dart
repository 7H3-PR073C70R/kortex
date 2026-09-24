import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class CircularSocialButton extends StatelessWidget {
  const CircularSocialButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.semanticsLabel,
    super.key,
  });

  final Widget icon;
  final Color color;
  final VoidCallback onPressed;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 65 : 35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: color.withAlpha(isHovered ? 120 : 70),
                    blurRadius: isHovered ? 14 : 8,
                    offset: Offset(0, isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Center(child: icon),
            ),
          );
        },
      ),
    );
  }
}

class GooglePlusIcon extends StatelessWidget {
  const GooglePlusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G+',
      style: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
      ),
    );
  }
}

class CircularArrowButton extends StatelessWidget {
  const CircularArrowButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(isHovered ? 130 : 80),
                    blurRadius: isHovered ? 12 : 7,
                    offset: Offset(0, isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
