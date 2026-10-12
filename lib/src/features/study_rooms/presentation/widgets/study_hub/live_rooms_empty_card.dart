import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_room_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Card displayed when no live focus rooms match the selected track filter or search query.
class LiveRoomsEmptyCard extends StatelessWidget {
  const LiveRoomsEmptyCard({
    required this.selectedFilter,
    required this.userTrack,
    required this.onClearFilter,
    super.key,
  });

  final String selectedFilter;
  final String? userTrack;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surfacePrimary,
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.surfaceBorder.withAlpha(isDark ? 40 : 20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_rounded,
            size: 44,
            color: colors.primary.withAlpha(160),
          ),
          const SizedBox(height: 12),
          Text(
            selectedFilter == 'All'
                ? l10n.noActiveRooms
                : 'No active focus rooms for "$selectedFilter"',
            style: typography.subhead.bold.copyWith(
              color: colors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            selectedFilter == 'All'
                ? 'Launch a new room to start studying with peers.'
                : 'Be the first scholar in your $selectedFilter track to start a Silent Focus Room! Peers in your track will be notified.',
            style: typography.caption.regular.copyWith(
              color: colors.textSecondary,
              height: 1.35,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  final activeTrackName = selectedFilter == 'All'
                      ? (userTrack ?? 'General')
                      : selectedFilter;
                  unawaited(
                    CreateStudyRoomSheet.show(
                      context,
                      initialTitle: '$activeTrackName Silent Focus Hub',
                      initialSubject: '$activeTrackName-STUDY-HUB',
                      initialCategory: activeTrackName,
                      onSubmit: ({
                        required title,
                        required subject,
                        required category,
                        required pomodoroMinutes,
                        ambientSoundTrack = 'lofi',
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
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadius.radiusCard,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Launch $selectedFilter Room',
                        style: typography.caption.bold.copyWith(
                          color: colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedFilter != 'All')
                OutlinedButton(
                  onPressed: onClearFilter,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.surfaceBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.radiusCard,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: Text(l10n.studyHubViewAllTracks),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
