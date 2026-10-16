import 'dart:async';
import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';
import 'package:kortex/src/shared/widgets/syllabot_avatar.dart';

/// Sticky banner displayed when user has not yet completed initial study pace calibration.
class UncalibratedProfileBanner extends StatelessWidget {
  const UncalibratedProfileBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Semantics(
      container: true,
      label: l10n.dashboardUncalibratedSemantics,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppRadius.panel,
              ),
              gradient: LinearGradient(
                colors: [
                  colors.primary.withAlpha(isDark ? 55 : 30),
                  colors.syllabotAccent.withAlpha(
                    isDark ? 35 : 18,
                  ),
                ],
              ),
              border: Border.all(
                color: colors.primary.withAlpha(
                  isDark ? 100 : 70,
                ),
              ),
            ),
            child: Row(
              children: [
                const SyllabotAvatar(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.dashboardUncalibratedTitle,
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.dashboardUncalibratedSubtitle,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    unawaited(
                      context.router.push(
                        const OnboardingCalibrationRoute(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(
                        AppRadius.badge,
                      ),
                    ),
                    child: Text(
                      l10n.dashboardCalibrateButton,
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: 200.ms)
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.1, end: 0, curve: Curves.easeOutQuint);
  }
}
