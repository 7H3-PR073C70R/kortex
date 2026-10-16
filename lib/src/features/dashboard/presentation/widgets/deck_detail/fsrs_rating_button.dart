import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Rating button for FSRS-6 spaced repetition review intervals (Hard, Good, Easy).
class FsrsRatingButton extends StatelessWidget {
  const FsrsRatingButton({
    required this.label,
    required this.interval,
    required this.color,
    required this.onTap,
    super.key,
    this.icon,
  });

  final String label;
  final String interval;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Semantics(
      button: true,
      label: '$label, $interval',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              onTap();
            },
            child: AnimatedContainer(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              padding: EdgeInsets.symmetric(
                vertical: isDesktop ? 14 : 10,
                horizontal: isDesktop ? 16 : 10,
              ),
              decoration: BoxDecoration(
                color: isHovered
                    ? color.withAlpha(isDark ? 65 : 45)
                    : color.withAlpha(isDark ? 38 : 24),
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isHovered
                      ? color.withAlpha(200)
                      : color.withAlpha(isDark ? 120 : 85),
                  width: isHovered ? 1.5 : 1.2,
                ),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: color.withAlpha(isDark ? 70 : 35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: isDesktop
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: color, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: typography.body.bold.copyWith(
                                color: color,
                                fontSize: 14.5,
                              ),
                            ),
                            Text(
                              interval,
                              style: typography.caption.bold.copyWith(
                                color: color.withAlpha(210),
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: color, size: 18),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          label,
                          style: typography.caption.bold.copyWith(
                            color: color,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(isDark ? 55 : 35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            interval,
                            style: typography.caption.bold.copyWith(
                              color: isDark ? Colors.white : color,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}
