import 'package:flutter/material.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_filter_bottom_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_forum_feed_list.dart';

/// Forum feed shown as a Hub sub-tab on compact layouts where the
/// bottom navigation bar has no dedicated Forum destination.
class StudyHubForumTab extends StatelessWidget {
  const StudyHubForumTab({
    required this.state,
    required this.targetTrack,
    super.key,
  });

  final CommunityState state;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final track = targetTrack?.trim();
    final effectiveTrack =
        (track != null && track.isNotEmpty && track != 'General')
            ? track
            : 'WAEC';

    return CommunityForumFeedList(
      state: state,
      searchQuery: state.forumSearchQuery,
      availableTracks: getAvailableTracks(targetTrack),
      effectiveTrack: effectiveTrack,
    );
  }
}
