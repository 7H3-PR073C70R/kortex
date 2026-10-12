import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/constants/app_spacing.dart';
import 'package:kortex/src/core/constants/pref_keys.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/local_storage_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/syllabot_settings_section_container.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Section widget for configuring the Socratic reasoning strategy.
class SocraticReasoningSection extends StatelessWidget {
  const SocraticReasoningSection({
    required this.socraticMode,
    this.localStorageService,
    super.key,
  });

  final ValueNotifier<SocraticMode> socraticMode;
  final LocalStorageService? localStorageService;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final activeMode = socraticMode.value;

    return SyllabotSettingsSectionContainer(
      title: 'SOCRATIC REASONING ENGINE',
      subtitle: 'Select how Syllabot structures tutoring & explanations',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Mode Hero Display Card
          AnimatedContainer(
            duration: AppMotion.snappy,
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(isDark ? 35 : 20),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 110 : 80),
                width: 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(40),
                    borderRadius: AppRadius.radiusCard,
                  ),
                  child: Center(
                    child: Text(
                      getSocraticModeIcon(activeMode),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              activeMode.label,
                              style: typography.body.bold.copyWith(
                                color: colors.primary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          AppSpacing.horizontalSpaceSmall,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: AppRadius.radiusMicro,
                            ),
                            child: Text(
                              'ACTIVE',
                              style: typography.caption.bold.copyWith(
                                color: colors.white,
                                fontSize: 9.5,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeMode.description,
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mode Selector Chips Grid (2 Rows)
          Text(
            'CHOOSE STRATEGY',
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary.withAlpha(140),
              fontSize: 10,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: SocraticMode.values.map((mode) {
              final isSelected = mode == activeMode;
              return PlatformHoverBuilder(
                builder: (context, isHovered, child) {
                  return AnimatedScale(
                    scale: isHovered && !isSelected ? 1.02 : 1.0,
                    duration: AppMotion.snappy,
                    curve: Curves.easeOutCubic,
                    child: child,
                  );
                },
                child: ShrinkableButton(
                  onTap: () {
                    AppFeedback.selection();
                    socraticMode.value = mode;
                    if (localStorageService != null) {
                      unawaited(
                        localStorageService!.savePreference(
                          key: PrefKeys.syllabotSocraticMode,
                          data: mode.name,
                        ),
                      );
                    }
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors.primary
                          : colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : colors.surfaceBorder.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          getSocraticModeIcon(mode),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mode.label,
                          style: typography.caption.bold.copyWith(
                            color: isSelected
                                ? colors.white
                                : colors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
