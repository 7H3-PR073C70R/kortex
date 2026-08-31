import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/live_focus_room_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/marketplace_deck_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/streak_leaderboard_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shimmer_placeholder.dart';

@RoutePage()
class CommunityHubPage extends HookWidget {
  const CommunityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommunityHubBloc>(
      create: (_) => locator<CommunityHubBloc>()
        ..add(const LoadCommunityHubEvent()),
      child: const _CommunityHubView(),
    );
  }
}

class _CommunityHubView extends HookWidget {
  const _CommunityHubView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final tabController = useTabController(initialLength: 4);

    useEffect(() {
      void listener() {
        context
            .read<CommunityHubBloc>()
            .add(SwitchCommunityTabEvent(tabController.index));
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    return Scaffold(
      backgroundColor:
          isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.communityTitle,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceSecondary.withAlpha(100),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: tabController,
              indicator: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: colors.textSecondary,
              labelStyle: typography.caption.bold,
              unselectedLabelStyle: typography.caption.medium,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: l10n.liveRoomsTab),
                Tab(text: l10n.forumTab),
                Tab(text: l10n.marketplaceTab),
                Tab(text: l10n.leaderboardTab),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        onPressed: () {
          unawaited(
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => CreatePostBottomSheet(
                onSubmit: ({
                  required title,
                  required content,
                  required track,
                  latexContent,
                }) {
                  context.read<CommunityHubBloc>().add(
                        CreateForumPostEvent(
                          title: title,
                          content: content,
                          track: track,
                          latexContent: latexContent,
                        ),
                      );
                },
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.createPostButton,
          style: typography.footnote.bold.copyWith(color: Colors.white),
        ),
      ),
      body: BlocConsumer<CommunityHubBloc, CommunityState>(
        listener: (context, state) {
          if (state.lastClonedDeckId != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.deckClonedSuccessNotice),
                backgroundColor: colors.primary,
                action: SnackBarAction(
                  label: 'Study Now',
                  textColor: Colors.white,
                  onPressed: () {
                    unawaited(
                      context.router.push(
                        StudySessionRoute(deckId: state.lastClonedDeckId!),
                      ),
                    );
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == CommunityStatus.loading &&
              state.studyRooms.isEmpty &&
              state.forumPosts.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerPlaceholder(
                width: double.infinity,
                height: 300,
                borderRadius: 20,
              ),
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;

              if (isDesktop) {
                // Desktop: 2-Panel Layout
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TabBarView(
                          controller: tabController,
                          children: [
                            _LiveRoomsList(state: state),
                            _ForumPostsList(state: state),
                            _MarketplaceDecksList(state: state),
                            StreakLeaderboardWidget(
                              entries: state.leaderboardEntries,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: SingleChildScrollView(
                          child: StreakLeaderboardWidget(
                            entries: state.leaderboardEntries,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Mobile: Single-Column Tab View
              return TabBarView(
                controller: tabController,
                children: [
                  _LiveRoomsList(state: state),
                  _ForumPostsList(state: state),
                  _MarketplaceDecksList(state: state),
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: StreakLeaderboardWidget(
                      entries: state.leaderboardEntries,
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LiveRoomsList extends StatelessWidget {
  const _LiveRoomsList({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    if (state.studyRooms.isEmpty) {
      return Center(
        child: Text(
          'No active study rooms right now.',
          style: context.typography.footnote.medium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.studyRooms.length,
      itemBuilder: (context, index) {
        final room = state.studyRooms[index];
        return LiveFocusRoomCard(
          room: room,
          onJoinTap: () {
            unawaited(context.router.push(LiveStudyRoomRoute(room: room)));
          },
        );
      },
    );
  }
}

class _ForumPostsList extends StatelessWidget {
  const _ForumPostsList({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    if (state.forumPosts.isEmpty) {
      return Center(
        child: Text(
          'No forum posts found.',
          style: context.typography.footnote.medium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.forumPosts.length,
      itemBuilder: (context, index) {
        final post = state.forumPosts[index];
        return TrackForumPostCard(
          post: post,
          onTap: () {
            unawaited(context.router.push(ForumThreadDetailRoute(post: post)));
          },
        );
      },
    );
  }
}

class _MarketplaceDecksList extends StatelessWidget {
  const _MarketplaceDecksList({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    if (state.sharedDecks.isEmpty) {
      return Center(
        child: Text(
          'No community decks available yet.',
          style: context.typography.footnote.medium.copyWith(
            color: context.colors.textSecondary,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.sharedDecks.length,
      itemBuilder: (context, index) {
        final deck = state.sharedDecks[index];
        return MarketplaceDeckCard(
          deck: deck,
          onTap: () {
            unawaited(
              context.router.push(
                DeckMarketplaceDetailRoute(deck: deck),
              ),
            );
          },
          onCloneTap: () {
            context.read<CommunityHubBloc>().add(CloneDeckEvent(deck.id));
          },
        );
      },
    );
  }
}
