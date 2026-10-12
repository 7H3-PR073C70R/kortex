import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';

/// Reusable section container for Syllabot AI settings modules.
class SyllabotSettingsSectionContainer extends StatelessWidget {
  const SyllabotSettingsSectionContainer({
    required this.title,
    required this.child,
    this.subtitle = '',
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary.withAlpha(170),
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: typography.caption.regular.copyWith(
                    color: colors.textSecondary.withAlpha(120),
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfacePrimary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: colors.surfaceBorder.withAlpha(80),
            ),
          ),
          child: child,
        ),
      ],
    );
  }
}

/// Helper method mapping Socratic reasoning modes to their display emojis.
String getSocraticModeIcon(SocraticMode mode) {
  switch (mode) {
    case SocraticMode.stepByStep:
      return '🪜';
    case SocraticMode.directAnswer:
      return '🎯';
    case SocraticMode.examSim:
      return '📝';
    case SocraticMode.deepResearch:
      return '🔬';
    case SocraticMode.feynmanTeachBack:
      return '🧠';
  }
}
