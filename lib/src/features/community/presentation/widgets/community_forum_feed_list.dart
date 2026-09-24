import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/pages/create_forum_discussion_page.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_forum_empty_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_pulse_banner.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';

/// Scrollable feed list displaying community forum posts with local filtering,
/// refresh indicators, ambient pulse banner, and infinite scroll pagination.
class CommunityForumFeedList extends HookWidget {
  const CommunityForumFeedList({
    required this.state,
    required this.searchQuery,
    required this.availableTracks,
    required this.effectiveTrack,
    super.key,
  });

  final CommunityState state;
  final String searchQuery;
  final List<String> availableTracks;
  final String effectiveTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final scrollController = useScrollController();
    final isPulseBannerDismissed = useState<bool>(false);

    useEffect(
      () {
        void onScroll() {
          if (!scrollController.hasClients) return;
          final maxScroll = scrollController.position.maxScrollExtent;
          final currentScroll = scrollController.position.pixels;
          if (maxScroll - currentScroll <= 200) {
            if (!state.isLoadingMoreForumPosts && state.hasMoreForumPosts) {
              context.read<CommunityHubBloc>().add(
                const FetchMoreForumPostsEvent(),
              );
            }
          }
        }

        scrollController.addListener(onScroll);
        return () => scrollController.removeListener(onScroll);
      },
      [
        scrollController,
        state.isLoadingMoreForumPosts,
        state.hasMoreForumPosts,
      ],
    );

    // Apply local search filtering if user typed in search bar (backend handles sort)
    final filteredPosts = useMemoized(() {
      if (searchQuery.isEmpty) return state.forumPosts;
      final query = searchQuery.toLowerCase();
      return state.forumPosts.where((p) {
        return p.title.toLowerCase().contains(query) ||
            p.content.toLowerCase().contains(query) ||
            p.authorName.toLowerCase().contains(query) ||
            p.syllabusTag.toLowerCase().contains(query);
      }).toList();
    }, [state.forumPosts, searchQuery]);

    return RefreshIndicator(
      onRefresh: () async {
        final completer = Completer<void>();
        context.read<CommunityHubBloc>().add(
          RefreshForumPostsEvent(completer: completer),
        );
        await completer.future;
      },
      color: colors.primary,
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Ambient Community Pulse Banner
          if (!isPulseBannerDismissed.value)
            SliverToBoxAdapter(
              child: CommunityPulseBanner(
                selectedTrack: state.selectedTrack,
                onDismiss: () {
                  isPulseBannerDismissed.value = true;
                },
              ),
            ),

          // Posts Feed or Empty State
          if (filteredPosts.isEmpty)
            SliverToBoxAdapter(
              child: CommunityForumEmptyState(
                searchQuery: searchQuery,
                selectedTrack: state.selectedTrack,
                effectiveTrack: effectiveTrack,
                onClearSearch: () {
                  context.read<CommunityHubBloc>().add(
                    const SearchForumPostsEvent(''),
                  );
                },
                onStartDiscussion: () async {
                  final hubBloc = context.read<CommunityHubBloc>();
                  final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: hubBloc,
                        child: CreateForumDiscussionPage(
                          initialTrack: state.selectedTrack == 'All'
                              ? effectiveTrack
                              : state.selectedTrack,
                        ),
                      ),
                    ),
                  );
                  if (created == true) {
                    hubBloc.add(
                      ChangeForumSortFilterEvent(
                        hubBloc.state.selectedForumFilter,
                      ),
                    );
                  }
                },
                onExploreAll: () {
                  context.read<CommunityHubBloc>().add(
                    const ChangeTrackFilterEvent('All'),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final post = filteredPosts[index];
                    final postCard = TrackForumPostCard(
                      post: post,
                      onTap: () {
                        unawaited(
                          context.router
                              .push(
                                ForumThreadDetailRoute(post: post),
                              )
                              .then((_) {
                                if (context.mounted) {
                                  final bloc = context.read<CommunityHubBloc>();
                                  bloc.add(
                                    ChangeForumSortFilterEvent(
                                      bloc.state.selectedForumFilter,
                                    ),
                                  );
                                }
                              }),
                        );
                      },
                      onUpvoteTap: () {
                        final direction = post.userVote == 1 ? 0 : 1;
                        context.read<CommunityHubBloc>().add(
                          VoteForumPostEvent(
                            postId: post.id,
                            direction: direction,
                          ),
                        );
                      },
                      onDownvoteTap: () {
                        final direction = post.userVote == -1 ? 0 : -1;
                        context.read<CommunityHubBloc>().add(
                          VoteForumPostEvent(
                            postId: post.id,
                            direction: direction,
                          ),
                        );
                      },
                    );

                    if (index < 5) {
                      return postCard
                          .animate(delay: (index * 60).ms)
                          .fadeIn(
                            duration: 220.ms,
                            curve: Curves.easeOut,
                          )
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            duration: 220.ms,
                            curve: Curves.easeOutCubic,
                          );
                    }
                    return postCard;
                  },
                  childCount: filteredPosts.length,
                ),
              ),
            ),

          // Loading more indicator
          if (state.isLoadingMoreForumPosts)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
