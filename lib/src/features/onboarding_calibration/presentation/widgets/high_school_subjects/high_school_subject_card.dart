import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/features/onboarding_calibration/presentation/widgets/curriculum_icon_resolver.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Compact high-density subject card with dynamic stream accent,
/// code badge, and smooth animated checkmark.
class HighSchoolSubjectCard extends StatelessWidget {
  const HighSchoolSubjectCard({
    required this.course,
    required this.streamName,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final CuratedCourseEntity course;
  final String streamName;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final resolvedIcon = resolveCurriculumIcon(course.iconName);

    return Semantics(
      button: true,
      selected: isSelected,
      label: '${course.title}, ${course.courseCode}, $streamName',
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.radiusPanel,
                color: isSelected
                    ? colors.primary.withAlpha(
                        isDark ? (isHovered ? 72 : 55) : (isHovered ? 40 : 28),
                      )
                    : isHovered
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(130)
                          : colors.surfacePrimary)
                    : (isDark
                          ? colors.surfaceSecondary.withAlpha(90)
                          : colors.surfacePrimary.withAlpha(190)),
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : isHovered
                      ? (isDark
                            ? colors.surfaceBorderHighlight
                            : colors.primary.withAlpha(90))
                      : (isDark
                            ? colors.surfaceBorderHighlight.withAlpha(60)
                            : colors.surfaceBorder),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected || isHovered
                    ? [
                        BoxShadow(
                          color: colors.black.withAlpha(
                            isDark
                                ? (isSelected ? 50 : 30)
                                : (isSelected ? 20 : 10),
                          ),
                          blurRadius: isHovered ? 10 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  // Subject Icon Container
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(isDark ? 45 : 30),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: accentColor.withAlpha(80),
                      ),
                    ),
                    child: Icon(
                      resolvedIcon,
                      size: 19,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Code Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                course.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: typography.subhead.bold.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 14,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? colors.surfaceBorderHighlight.withAlpha(
                                        50,
                                      )
                                    : colors.surfaceBorder.withAlpha(100),
                                borderRadius: AppRadius.radiusMicro,
                              ),
                              child: Text(
                                course.courseCode,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              streamName,
                              style: typography.caption.semiBold.copyWith(
                                color: accentColor,
                                fontSize: 11.5,
                              ),
                            ),
                            Text(
                              ' • ${course.totalMaterials} materials',
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Animated Checkbox
                  AnimatedContainer(
                    duration: AppMotion.snappy,
                    curve: AppMotion.easeOutCubic,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : colors.transparent,
                      borderRadius: AppRadius.radiusMicro,
                      border: Border.all(
                        color: isSelected
                            ? colors.primary
                            : (isDark
                                  ? colors.surfaceBorderHighlight.withAlpha(120)
                                  : colors.surfaceBorder),
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: colors.white,
                          )
                        : null,
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
