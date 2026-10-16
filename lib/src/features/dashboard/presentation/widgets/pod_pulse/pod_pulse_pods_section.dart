import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/pod_pulse/pod_pulse_card_item.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_circle_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_circle_detail_sheet.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Available study pods horizontal list and empty state section.
class PodPulsePodsSection extends StatelessWidget {
  const PodPulsePodsSection({
    required this.circles,
    required this.trackLabel,
    required this.targetTrack,
    this.communityBloc,
    super.key,
  });

  final List<StudyCircleEntity> circles;
  final String trackLabel;
  final String? targetTrack;
  final CommunityHubBloc? communityBloc;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    final bloc = communityBloc;

    void openCreateSheet() {
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
            if (bloc != null) {
              bloc.add(
                CreateStudyCircleEvent(
                  name: name,
                  track: track,
                  targetWeeklyMinutes: targetWeeklyMinutes,
                ),
              );
              context.showSnackBar(
                message: 'Study Pod "$name" created successfully!',
              );
            }
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: neural.hairlineSoft),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'AVAILABLE STUDY PODS',
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.bold.copyWith(
                          color: neural.slate400,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: neural.obsidian800,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${circles.length}',
                        style: typography.caption.bold.copyWith(
                          color: neural.slate200,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ShrinkableButton(
                onTap: openCreateSheet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 14,
                        color: neural.emerald400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Create Pod',
                        style: typography.caption.bold.copyWith(
                          color: neural.emerald400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (circles.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 28,
                    color: neural.slate400,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No live pods for $trackLabel yet',
                    style: typography.caption.medium.copyWith(
                      color: neural.slate400,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ShrinkableButton(
                    onTap: openCreateSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: neural.emerald.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: neural.emerald.withAlpha(77),
                        ),
                      ),
                      child: Text(
                        'Start a Pod Sprint',
                        style: typography.caption.bold.copyWith(
                          color: neural.emerald400,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: circles.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final circle = circles[index];
                return PodPulseCardItem(
                  circle: circle,
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    if (communityBloc != null) {
                      unawaited(
                        StudyCircleDetailSheet.show(
                          context,
                          circle,
                          bloc: communityBloc,
                        ),
                      );
                    }
                  },
                  onJoin: () {
                    unawaited(HapticFeedback.mediumImpact());
                    if (bloc != null) {
                      bloc.add(
                        JoinStudyCircleEvent(circle.id),
                      );
                      context.showSnackBar(
                        message: 'Joined ${circle.name}! Welcome to the Pod.',
                      );
                    }
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
