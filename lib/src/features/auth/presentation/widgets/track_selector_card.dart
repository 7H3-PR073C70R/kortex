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
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'gavel':
        return Icons.gavel_rounded;
      case 'engineering':
        return Icons.engineering_outlined;
      case 'trending_up':
        return Icons.trending_up_rounded;
      case 'menu_book':
        return Icons.menu_book_rounded;
      case 'terminal':
        return Icons.terminal_rounded;
      case 'record_voice_over':
        return Icons.record_voice_over_outlined;
      case 'translate':
        return Icons.translate_rounded;
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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withAlpha(isDark ? 35 : 18)
                : isDark
                    ? colors.surfaceSecondary
                    : colors.surfacePrimary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colors.primary
                  : colors.surfaceBorder.withAlpha(isDark ? 80 : 50),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 30 : 15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Track Icon Container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [
                            colors.primary,
                            colors.primary.withAlpha(200),
                          ]
                        : [
                            colors.primary.withAlpha(isDark ? 40 : 25),
                            colors.syllabotAccent.withAlpha(isDark ? 30 : 15),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _getIconData(track.iconName),
                  color: isSelected ? Colors.white : colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Title, Description & Badge
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            track.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.body.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withAlpha(40)
                                : colors.surfaceTertiary,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '~${track.examCountdownDays}d',
                            style: typography.caption.bold.copyWith(
                              color: isSelected
                                  ? colors.primary
                                  : colors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      track.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),

              // Selection Checkmark
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.textSecondary.withAlpha(70),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 14,
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
