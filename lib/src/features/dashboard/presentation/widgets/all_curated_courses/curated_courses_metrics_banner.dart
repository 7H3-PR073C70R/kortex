import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/core/themes/color/app_theme_colors_extension.dart';
import 'package:kortex/src/core/themes/typography/typography_theme_extension.dart';

/// Top metrics summary banner for enrolled curated courses.
class CuratedCoursesMetricsBanner extends StatelessWidget {
  const CuratedCoursesMetricsBanner({
    required this.activeCoursesCount,
    required this.studyDecksCount,
    required this.qBanksCount,
    required this.colors,
    required this.typography,
    required this.isDark,
    super.key,
  });

  final int activeCoursesCount;
  final int studyDecksCount;
  final int qBanksCount;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(140)
                  : colors.surfacePrimary.withAlpha(210),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: isDark
                    ? colors.surfaceBorderHighlight.withAlpha(60)
                    : colors.surfaceBorder.withAlpha(130),
                width: 1.1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: 'Active Courses',
                  value: '$activeCoursesCount',
                  icon: Icons.school_rounded,
                  colors: colors,
                  typography: typography,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(60)
                      : colors.surfaceBorder.withAlpha(120),
                ),
                _StatItem(
                  label: 'Study Decks',
                  value: '$studyDecksCount',
                  icon: Icons.style_rounded,
                  colors: colors,
                  typography: typography,
                ),
                Container(
                  height: 30,
                  width: 1,
                  color: isDark
                      ? colors.surfaceBorderHighlight.withAlpha(60)
                      : colors.surfaceBorder.withAlpha(120),
                ),
                _StatItem(
                  label: 'Available',
                  value: '$qBanksCount Q-Banks',
                  icon: Icons.verified_rounded,
                  colors: colors,
                  typography: typography,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
    required this.typography,
  });

  final String label;
  final String value;
  final IconData icon;
  final AppThemeColorsExtension colors;
  final TypographyThemeExtension typography;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
