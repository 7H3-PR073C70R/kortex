import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/auth/domain/entities/course_track_entity.dart';
import 'package:kortex/src/features/auth/presentation/widgets/track_selector_card.dart';

/// Embedded interactive track selector directly rendered inside the AI
/// onboarding chat stream.
class InlineTrackPickerBubble extends StatelessWidget {
  const InlineTrackPickerBubble({
    required this.selectedTrack,
    required this.onTrackSelected,
    this.tracks = CourseTrackEntity.defaultTracks,
    super.key,
  });

  final String selectedTrack;
  final ValueChanged<CourseTrackEntity> onTrackSelected;
  final List<CourseTrackEntity> tracks;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(200)
            : colors.surfacePrimary.withAlpha(240),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 50 : 30),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 40 : 15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Your Target Exam / Curriculum',
            style: typography.subhead.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ...tracks.map((track) {
            final isSelected = selectedTrack == track.id;
            return TrackSelectorCard(
              track: track,
              isSelected: isSelected,
              onTap: () => onTrackSelected(track),
            );
          }),
        ],
      ),
    );
  }
}
