import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/pod_pulse/pod_pulse_header_section.dart';
import 'package:kortex/src/features/dashboard/presentation/widgets/pod_pulse/pod_pulse_pods_section.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_circle_entity.dart';

/// Study Circle Pod Pulse live widget for the executive dashboard.
class StudyCirclePodPulseCard extends StatefulWidget {
  const StudyCirclePodPulseCard({
    this.targetTrack,
    this.communityBloc,
    this.userActivityService,
    super.key,
  });

  final String? targetTrack;
  final CommunityHubBloc? communityBloc;
  final UserActivityService? userActivityService;

  @override
  State<StudyCirclePodPulseCard> createState() =>
      _StudyCirclePodPulseCardState();
}

class _StudyCirclePodPulseCardState extends State<StudyCirclePodPulseCard> {
  CommunityHubBloc? _bloc;
  UserActivityService? _activityService;

  @override
  void initState() {
    super.initState();
    _bloc = widget.communityBloc ??
        (locator.isRegistered<CommunityHubBloc>()
            ? locator<CommunityHubBloc>()
            : null);

    _activityService = widget.userActivityService ??
        (locator.isRegistered<UserActivityService>()
            ? locator<UserActivityService>()
            : null);

    if (_bloc != null) {
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
    final targetTrack = widget.targetTrack;

    final trackLabel = (targetTrack != null && targetTrack.trim().isNotEmpty)
        ? targetTrack.trim()
        : 'All Tracks';

    final communityBloc = _bloc;
    final userXp = _activityService?.getXpPoints() ?? 0;

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
          : (_activityService?.getWeeklyMinutesStudied() ?? 0);

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
            PodPulseHeaderSection(
              trackLabel: trackLabel,
              activeScholarsStr: activeStr,
              focusMinutesStr: minutesStr,
              karmaStr: karmaStr,
            ),
            PodPulsePodsSection(
              circles: circles,
              trackLabel: trackLabel,
              targetTrack: targetTrack,
              communityBloc: communityBloc,
            ),
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
