import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class TrackSelectorCard extends StatelessWidget {
  const TrackSelectorCard({
    required this.track,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final CourseTrackEntity track;
  final bool isSelected;
  final VoidCallback onTap;

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'calculate':
        return Icons.calculate_outlined;
      case 'biotech':
        return Icons.biotech_outlined;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final semanticsLabel = '${track.name} Track. ${track.description}. '
        'Default target: ${track.defaultDailyTarget} cards per day. '
        '${isSelected ? "Selected" : "Not selected"}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      selected: isSelected,
      child: ShrinkableButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withAlpha(isDark ? 45 : 25)
                : isDark
                    ? colors.surfaceSecondary
                    : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.primary.withAlpha(isDark ? 30 : 15),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? colors.primary.withAlpha(isDark ? 40 : 20)
                    : Colors.black.withAlpha(isDark ? 40 : 10),
                blurRadius: isSelected ? 14 : 6,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Track Icon Container
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [
                            colors.primary,
                            colors.primary.withAlpha(200),
                          ]
                        : [
                            colors.primary.withAlpha(isDark ? 50 : 30),
                            colors.syllabotAccent.withAlpha(isDark ? 40 : 20),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIconData(track.iconName),
                  color: isSelected ? Colors.white : colors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),

              // Title, Description & Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          track.name,
                          style: typography.title3.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withAlpha(50)
                                : colors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '~${track.examCountdownDays}d exam',
                            style: typography.caption.bold.copyWith(
                              color: isSelected
                                  ? colors.primary
                                  : colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.description,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Checkmark
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.textSecondary.withAlpha(80),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
