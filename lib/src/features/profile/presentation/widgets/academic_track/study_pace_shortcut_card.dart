import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Navigation shortcut card leading to DeckPaceSettingsRoute for advanced FSRS tuning.
class StudyPaceShortcutCard extends StatelessWidget {
  const StudyPaceShortcutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedScale(
          scale: isHovered ? 1.005 : 1.0,
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: () {
          AppFeedback.light();
          unawaited(
            context.router.push(const DeckPaceSettingsRoute()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(60),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(30),
                  borderRadius: AppRadius.radiusBadge,
                ),
                child: Icon(
                  Icons.tune_rounded,
                  color: colors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Study Pace & Daily Reminders',
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calibrate desired retention, request interval optimization, and schedule daily review reminders.',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
