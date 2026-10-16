import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/constants/subject_catalog.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Quick-select preset pills allowing 1-tap combination toggling.
class HighSchoolSubjectPresetsBar extends StatelessWidget {
  const HighSchoolSubjectPresetsBar({
    required this.presets,
    required this.selectedSubjects,
    required this.onPresetTapped,
    super.key,
  });

  final List<SubjectCombinationPreset> presets;
  final List<String> selectedSubjects;
  final void Function(
    SubjectCombinationPreset preset, {
    required bool isPresetActive,
  }) onPresetTapped;

  @override
  Widget build(BuildContext context) {
    if (presets.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'QUICK PRESETS',
              style: typography.caption.semiBold.copyWith(
                color: colors.primary,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(25),
                borderRadius: AppRadius.radiusBadge,
              ),
              child: Text(
                '1-Tap',
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 9.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isPresetActive = preset.subjectTitles.every(
                selectedSubjects.contains,
              );

              return PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.mediumImpact());
                      onPresetTapped(preset, isPresetActive: isPresetActive);
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isPresetActive
                            ? colors.primary.withAlpha(
                                isDark
                                    ? (isHovered ? 80 : 65)
                                    : (isHovered ? 50 : 35),
                              )
                            : isHovered
                            ? (isDark
                                  ? colors.surfaceSecondary.withAlpha(140)
                                  : colors.surfacePrimary)
                            : (isDark
                                  ? colors.surfaceSecondary.withAlpha(100)
                                  : colors.surfacePrimary.withAlpha(190)),
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: isPresetActive
                              ? colors.primary
                              : isHovered
                              ? (isDark
                                    ? colors.surfaceBorderHighlight
                                    : colors.primary.withAlpha(90))
                              : (isDark
                                    ? colors.surfaceBorderHighlight.withAlpha(70)
                                    : colors.surfaceBorder),
                          width: isPresetActive ? 1.4 : 1,
                        ),
                        boxShadow: isPresetActive || isHovered
                            ? [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isDark
                                        ? (isPresetActive ? 40 : 25)
                                        : (isPresetActive ? 15 : 8),
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPresetActive
                                ? Icons.check_circle_rounded
                                : preset.icon,
                            size: 15,
                            color: isPresetActive
                                ? colors.primary
                                : (isHovered
                                      ? colors.textPrimary
                                      : colors.textSecondary),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            preset.title,
                            style: typography.caption.bold.copyWith(
                              color: isPresetActive
                                  ? colors.primary
                                  : colors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
