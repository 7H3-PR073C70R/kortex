import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/profile/presentation/widgets/academic_track/track_icon_helper.dart';
import 'package:kortex/src/features/profile/presentation/widgets/academic_track/track_selector_modal_sheet.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Single interactive Track card with tap-to-switch workflow.
class AcademicTrackCard extends StatelessWidget {
  const AcademicTrackCard({
    required this.track,
    required this.selectedTrack,
    super.key,
  });

  final CourseTrackEntity track;
  final ValueNotifier<String> selectedTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return AnimatedContainer(
          duration: AppMotion.snappy,
          curve: Curves.easeOutCubic,
          transform: isHovered
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          child: child,
        );
      },
      child: ShrinkableButton(
        onTap: () => showTrackSelectorModalSheet(
          context: context,
          selectedTrack: selectedTrack,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceSecondary,
            borderRadius: AppRadius.radiusDialog,
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 100 : 70),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.black.withAlpha(isDark ? 40 : 12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primary,
                          colors.syllabotAccent,
                        ],
                      ),
                      borderRadius: AppRadius.radiusCard,
                    ),
                    child: Icon(
                      getTrackIconData(track.iconName),
                      color: colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                track.name,
                                style: typography.body.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 15.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(40),
                                borderRadius: AppRadius.radiusBadge,
                              ),
                              child: Text(
                                '~${track.examCountdownDays}d exam',
                                style: typography.caption.bold.copyWith(
                                  color: colors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap to change track (11 available)',
                          style: typography.caption.regular.copyWith(
                            color: colors.syllabotAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: colors.surfaceBorder.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Change',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                track.description,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
