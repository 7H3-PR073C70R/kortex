import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_circle_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_circle_detail_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_animated_entrance.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Study Circle Pod Pulse live widget for the executive dashboard.
class StudyCirclePodPulseCard extends StatefulWidget {
  const StudyCirclePodPulseCard({
    this.targetTrack,
    super.key,
  });

  final String? targetTrack;

  @override
  State<StudyCirclePodPulseCard> createState() =>
      _StudyCirclePodPulseCardState();
}

class _StudyCirclePodPulseCardState extends State<StudyCirclePodPulseCard> {
  CommunityHubBloc? _bloc;

  @override
  void initState() {
    super.initState();
    if (locator.isRegistered<CommunityHubBloc>()) {
      _bloc = locator<CommunityHubBloc>();
      if (_bloc!.state.status == CommunityStatus.initial) {
        _bloc!.add(const LoadCommunityHubEvent());
      } else if (_bloc!.state.studyCircles.isEmpty) {
        _bloc!.add(const LoadStudyCirclesEvent());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;
    final targetTrack = widget.targetTrack;

    final trackLabel = (targetTrack != null && targetTrack.trim().isNotEmpty)
        ? targetTrack.trim()
        : 'All Tracks';

    final communityBloc =
        _bloc ??
        (locator.isRegistered<CommunityHubBloc>()
            ? locator<CommunityHubBloc>()
            : null);

    final activityService = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>()
        : null;
    final userXp = activityService?.getXpPoints() ?? 0;

    Widget contentBuilder(CommunityState state) {
      final allCircles = state.studyCircles;
      final effectiveTrack = targetTrack?.trim();
      final trackCircles =
          (effectiveTrack != null &&
                  effectiveTrack.isNotEmpty &&
                  effectiveTrack != 'All Tracks' &&
                  effectiveTrack != 'All')
              ? allCircles
                  .where(
                    (c) =>
                        c.track.toLowerCase() ==
                        effectiveTrack.toLowerCase(),
                  )
                  .toList()
              : allCircles;

      final joinedCircles =
          allCircles.where((c) => c.isCurrentUserMember).toList();
      final combinedMap = <String, StudyCircleEntity>{};
      for (final c in joinedCircles) {
        combinedMap[c.id] = c;
      }
      for (final c in trackCircles) {
        combinedMap[c.id] = c;
      }
      final combined = combinedMap.values.toList();

      final circles = combined.isNotEmpty ? combined : allCircles;

      final totalActiveScholars = state.totalActiveScholars > 0
          ? state.totalActiveScholars
          : (circles.isNotEmpty ? circles.first.effectiveMemberCount : 1);

      final totalFocusMinutes = state.totalGroupFocusMinutes > 0
          ? state.totalGroupFocusMinutes
          : (activityService?.getWeeklyMinutesStudied() ?? 0);

      final activeStr = '$totalActiveScholars Online';
      final minutesStr = '${totalFocusMinutes}m';
      final karmaStr = '+$userXp';

      return Container(
        decoration: BoxDecoration(
          color: neural.glassPanel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: neural.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Pulse Beacon + POD PULSE + Live Tag + Track + View All
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppPulsingBeacon(
                              color: neural.emerald,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l10n.podPulseTitle,
                                overflow: TextOverflow.ellipsis,
                                style: typography.caption.bold.copyWith(
                                  color: neural.emerald400,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: neural.emerald.withAlpha(38),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: neural.emerald.withAlpha(77),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: neural.emerald,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LIVE SYNC',
                                    style: typography.caption.bold.copyWith(
                                      color: neural.emerald400,
                                      fontSize: 9,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          unawaited(HapticFeedback.lightImpact());
                          AppTabNavigation.navigateTo(
                            context,
                            AppMainTab.forum,
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                trackLabel,
                                style: typography.caption.medium.copyWith(
                                  color: neural.slate300,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 14,
                                color: neural.slate400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Metrics Summary Row
                  Row(
                    children: [
                      Expanded(
                        child: PodMetricChip(
                          icon: Icons.groups_rounded,
                          iconColor: neural.emerald400,
                          value: activeStr,
                          label: l10n.activeToday,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PodMetricChip(
                          icon: Icons.timer_outlined,
                          iconColor: neural.amber400,
                          value: minutesStr,
                          label: l10n.groupFocus,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PodMetricChip(
                          icon: Icons.bolt_rounded,
                          iconColor: neural.cyan400,
                          value: karmaStr,
                          valueColor: neural.cyan300,
                          label: l10n.podKarma,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Available Pods Cards Section
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
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        CreateStudyCircleSheet.show(
                          context,
                          initialTrack: targetTrack ?? 'General',
                          onSubmit:
                              ({
                                required name,
                                required track,
                                required targetWeeklyMinutes,
                              }) {
                                if (communityBloc != null) {
                                  communityBloc.add(
                                    CreateStudyCircleEvent(
                                      name: name,
                                      track: track,
                                      targetWeeklyMinutes:
                                          targetWeeklyMinutes,
                                    ),
                                  );
                                  context.showSnackBar(
                                    message:
                                        'Study Pod "$name" created successfully!',
                                  );
                                }
                              },
                        ),
                      );
                    },
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
                        onTap: () {
                          unawaited(
                            CreateStudyCircleSheet.show(
                              context,
                              initialTrack: targetTrack ?? 'General',
                              onSubmit:
                                  ({
                                    required name,
                                    required track,
                                    required targetWeeklyMinutes,
                                  }) {
                                    if (communityBloc != null) {
                                      communityBloc.add(
                                        CreateStudyCircleEvent(
                                          name: name,
                                          track: track,
                                          targetWeeklyMinutes:
                                              targetWeeklyMinutes,
                                        ),
                                      );
                                      context.showSnackBar(
                                        message:
                                            'Study Pod "$name" created successfully!',
                                      );
                                    }
                                  },
                            ),
                          );
                        },
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
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
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
                        if (communityBloc != null) {
                          communityBloc.add(
                            JoinStudyCircleEvent(circle.id),
                          );
                          context.showSnackBar(
                            message:
                                'Joined ${circle.name}! Welcome to the Pod.',
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    }

    if (communityBloc != null) {
      return BlocBuilder<CommunityHubBloc, CommunityState>(
        bloc: communityBloc,
        builder: (context, state) => contentBuilder(state),
      );
    }

    return contentBuilder(const CommunityState());
  }
}

class PodPulseCardItem extends StatelessWidget {
  const PodPulseCardItem({
    required this.circle,
    required this.onTap,
    required this.onJoin,
    super.key,
  });

  final StudyCircleEntity circle;
  final VoidCallback onTap;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    final isJoined = circle.isCurrentUserMember;
    final isFull = circle.isFull;
    final memberCount = circle.effectiveMemberCount;
    final maxMembers = circle.maxMembers;
    final progress = circle.weeklyProgressPercent;

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: onTap,
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: neural.obsidian850.withAlpha(200),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isJoined
                    ? neural.emerald.withAlpha(128)
                    : (isHovered
                          ? neural.emerald.withAlpha(77)
                          : neural.hairlineSoft),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        circle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.caption.bold.copyWith(
                          color: neural.slate100,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isJoined
                            ? neural.emerald.withAlpha(38)
                            : (isFull
                                  ? neural.amber400.withAlpha(25)
                                  : neural.cyan.withAlpha(25)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isJoined
                            ? 'JOINED'
                            : (isFull ? 'FULL' : '$memberCount/$maxMembers'),
                        style: typography.caption.bold.copyWith(
                          color: isJoined
                              ? neural.emerald400
                              : (isFull ? neural.amber400 : neural.cyan300),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  circle.podQuest,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.medium.copyWith(
                    color: neural.slate400,
                    fontSize: 10,
                  ),
                ),

                // Weekly Goal Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weekly Sprint',
                          style: typography.caption.medium.copyWith(
                            color: neural.slate400,
                            fontSize: 9,
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: typography.caption.bold.copyWith(
                            color: neural.emerald400,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 4,
                        backgroundColor: neural.obsidian800,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          neural.emerald400,
                        ),
                      ),
                    ),
                  ],
                ),

                // Bottom row: Member Avatars / Action Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Member Avatar Stack
                    Row(
                      children: [
                        for (
                          var i = 0;
                          i < (circle.members.length.clamp(0, 3));
                          i++
                        )
                          Align(
                            widthFactor: 0.6,
                            child: CircleAvatar(
                              radius: 9,
                              backgroundColor: neural.emerald.withAlpha(200),
                              child: Text(
                                circle.members[i].userName.isNotEmpty
                                    ? circle.members[i].userName[0]
                                          .toUpperCase()
                                    : 'S',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (circle.members.isEmpty)
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: neural.emerald.withAlpha(200),
                            child: const Text(
                              'P',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!isJoined && !isFull)
                      ShrinkableButton(
                        onTap: onJoin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: neural.emerald.withAlpha(38),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: neural.emerald.withAlpha(102),
                            ),
                          ),
                          child: Text(
                            'Join Pod',
                            style: typography.caption.bold.copyWith(
                              color: neural.emerald400,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        isJoined ? 'Tap details' : 'Pod Full',
                        style: typography.caption.medium.copyWith(
                          color: neural.slate400,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PodMetricChip extends StatelessWidget {
  const PodMetricChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.valueColor,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: neural.obsidian850.withAlpha(153),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: neural.hairlineSoft),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: typography.caption.bold.copyWith(
                    color: valueColor ?? neural.slate300,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: typography.caption.regular.copyWith(
              color: neural.slate400,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
