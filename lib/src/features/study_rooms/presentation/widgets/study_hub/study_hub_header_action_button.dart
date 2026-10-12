import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/pages/create_forum_discussion_page.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/publish_deck_modal_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_circle_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_room_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Top bar context-aware action button dynamically customized for the active [StudyHubSubTab].
class StudyHubHeaderActionButton extends StatelessWidget {
  const StudyHubHeaderActionButton({
    required this.subTab,
    required this.isWide,
    required this.targetTrack,
    super.key,
  });

  final StudyHubSubTab subTab;
  final bool isWide;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final IconData icon;
    final String label;
    final VoidCallback onTap;

    switch (subTab) {
      case StudyHubSubTab.forum:
        icon = Icons.edit_note_rounded;
        label = 'Post Thread';
        onTap = () async {
          unawaited(HapticFeedback.lightImpact());
          final hubBloc = context.read<CommunityHubBloc>();
          final initialTrack = targetTrack ?? hubBloc.state.selectedTrack;
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: hubBloc,
                child: CreateForumDiscussionPage(
                  initialTrack: initialTrack.isNotEmpty ? initialTrack : 'WAEC',
                ),
              ),
            ),
          );
          if (created == true) {
            hubBloc.add(
              ChangeForumSortFilterEvent(hubBloc.state.selectedForumFilter),
            );
          }
        };
      case StudyHubSubTab.liveRooms:
        icon = Icons.add_rounded;
        label = l10n.newRoomAction;
        onTap = () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(
            CreateStudyRoomSheet.show(
              context,
              onSubmit: ({
                required title,
                required subject,
                required category,
                required pomodoroMinutes,
                ambientSoundTrack = 'Lo-Fi Beats',
                activeGoal,
                isSilentFocus = true,
              }) {
                context.read<CommunityHubBloc>().add(
                  CreateRoomEvent(
                    title: title,
                    subject: subject,
                    category: category,
                    pomodoroMinutes: pomodoroMinutes,
                    ambientSoundTrack: ambientSoundTrack,
                    activeGoal: activeGoal,
                    isSilentFocus: isSilentFocus,
                  ),
                );
                context.showSnackBar(
                  message: '✨ Launching Live Focus Room "$title"...',
                  type: SnackBarType.success,
                );
              },
            ),
          );
        };
      case StudyHubSubTab.studyCircles:
        icon = Icons.groups_rounded;
        label = 'Start Pod';
        onTap = () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(
            CreateStudyCircleSheet.show(
              context,
              initialTrack: targetTrack ?? 'General',
              onSubmit: ({
                required name,
                required track,
                required targetWeeklyMinutes,
              }) {
                context.read<CommunityHubBloc>().add(
                  CreateStudyCircleEvent(
                    name: name,
                    track: track,
                    targetWeeklyMinutes: targetWeeklyMinutes,
                  ),
                );
                context.showSnackBar(
                  message: '🎉 Study Pod "$name" created successfully!',
                  type: SnackBarType.success,
                );
              },
            ),
          );
        };
      case StudyHubSubTab.marketplace:
        icon = Icons.publish_rounded;
        label = 'Publish Deck';
        onTap = () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(
            PublishDeckModalSheet.show(
              context,
              onSubmit: ({
                required title,
                required subject,
                required description,
                required category,
                syllabusTag = 'General',
                totalCards = 10,
                cardsJson = const [],
              }) {
                context.read<CommunityHubBloc>().add(
                  PublishDeckEvent(
                    title: title,
                    subject: subject,
                    description: description,
                    category: category,
                    syllabusTag: syllabusTag,
                    totalCards: totalCards,
                    cardsJson: cardsJson,
                  ),
                );
              },
            ),
          );
        };
    }

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.03 : 1,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isHovered
                  ? colors.primary.withAlpha(isDark ? 65 : 45)
                  : colors.primary.withAlpha(isDark ? 40 : 25),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: isHovered
                    ? colors.primary
                    : colors.primary.withAlpha(isDark ? 80 : 50),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: colors.primary, size: 16),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: typography.caption.bold.copyWith(
                    color: colors.primary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
