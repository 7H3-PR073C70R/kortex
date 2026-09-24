import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_shimmer.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/marketplace_deck_card.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/publish_deck_modal_sheet.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_circle_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/create_study_room_sheet.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/live_focus_room_card.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_circle_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class StudyHubPage extends HookWidget {
  const StudyHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommunityHubBloc>(
      create: (_) =>
          locator<CommunityHubBloc>()..add(const LoadCommunityHubEvent()),
      child: const _StudyHubView(),
    );
  }
}

class _StudyHubView extends HookWidget {
  const _StudyHubView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final tabController = useTabController(initialLength: 2);
    useListenable(tabController);

    final authState = context.watch<AuthBloc?>()?.state;
    final targetTrack = authState?.userProfile?.targetTrack;

    return BlocListener<CommunityHubBloc, CommunityState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.errorMessage != previous.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null &&
            state.errorMessage!.trim().isNotEmpty) {
          context.showSnackBar(
            message: state.errorMessage!,
            type: SnackBarType.error,
          );
          context.read<CommunityHubBloc>().add(
            const ClearCommunityErrorEvent(),
          );
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? colors.backgroundPrimary
            : colors.surfacePrimary,
        appBar: AppBar(
          backgroundColor: colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Text(
            'Study Hub',
            style: typography.title2.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: tabController.index == 0
                  ? PlatformHoverBuilder(
                      builder: (context, isHovered, child) => AnimatedScale(
                        scale: isHovered ? 1.03 : 1,
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(
                              CreateStudyRoomSheet.show(
                                context,
                                onSubmit:
                                    ({
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
                                    },
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? colors.primary.withAlpha(isDark ? 65 : 45)
                                  : colors.primary.withAlpha(isDark ? 40 : 25),
                              borderRadius: AppRadius.radiusBadge,
                              border: Border.all(
                                color: isHovered
                                    ? colors.primary
                                    : colors.primary.withAlpha(
                                        isDark ? 80 : 50,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  color: colors.primary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.newRoomAction,
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
                    )
                  : PlatformHoverBuilder(
                      builder: (context, isHovered, child) => AnimatedScale(
                        scale: isHovered ? 1.03 : 1,
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.lightImpact());
                            unawaited(
                              PublishDeckModalSheet.show(
                                context,
                                onSubmit:
                                    ({
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
                          },
                          child: AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: AppMotion.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isHovered
                                  ? colors.primary.withAlpha(isDark ? 65 : 45)
                                  : colors.primary.withAlpha(isDark ? 40 : 25),
                              borderRadius: AppRadius.radiusBadge,
                              border: Border.all(
                                color: isHovered
                                    ? colors.primary
                                    : colors.primary.withAlpha(
                                        isDark ? 80 : 50,
                                      ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.publish_rounded,
                                  color: colors.primary,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Publish Deck',
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
                    ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: AppLiquidGlassTabBar(
                    tabs: [
                      l10n.liveRoomsTab,
                      l10n.marketplaceTab,
                    ],
                    selectedIndex: tabController.index,
                    onTabSelected: tabController.animateTo,
                    isCompact: true,
                  ),
                ),
              ),
            ),
          ),
        ),
        body: BlocConsumer<CommunityHubBloc, CommunityState>(
          listenWhen: (prev, curr) =>
              curr.lastClonedDeckId != null &&
              prev.lastClonedDeckId != curr.lastClonedDeckId,
          listener: (context, state) {
            if (state.lastClonedDeckId != null) {
              if (locator.isRegistered<DecksBloc>()) {
                locator<DecksBloc>().add(const DecksRefreshed());
              }
              if (locator.isRegistered<DashboardBloc>()) {
                locator<DashboardBloc>().add(const DashboardRefreshed());
              }
              context.showSnackBar(
                message: l10n.deckClonedSuccessNotice,
              );
            }
          },
          builder: (context, state) {
            if (state.status == CommunityStatus.loading &&
                state.studyRooms.isEmpty &&
                state.sharedDecks.isEmpty) {
              return CommunityHubShimmer(
                tabIndex: tabController.index == 0 ? 0 : 2,
              );
            }

            return TabBarView(
              controller: tabController,
              children: [
                // 1. Live Rooms & Study Circles
                _LiveRoomsTab(
                  state: state,
                  targetTrack: targetTrack,
                ),

                // 2. Deck Marketplace
                _DeckMarketplaceTab(state: state),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiveRoomsTab extends StatelessWidget {
  const _LiveRoomsTab({
    required this.state,
    required this.targetTrack,
  });

  final CommunityState state;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommunityHubBloc>().add(const LoadCommunityHubEvent());
      },
      color: colors.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Live Pomodoro Rooms Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.error,
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .fadeIn(duration: 800.ms)
                          .scaleXY(begin: 0.85, end: 1, duration: 800.ms),
                      const SizedBox(width: 8),
                      Text(
                        'Live Focus Rooms',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${state.studyRooms.length} active',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (state.studyRooms.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 40,
                            color: colors.textSecondary.withAlpha(120),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.noActiveRooms,
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final room = state.studyRooms[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: LiveFocusRoomCard(
                            room: room,
                            onJoinTap: () {
                              unawaited(
                                context.router.push(
                                  LiveStudyRoomRoute(room: room),
                                ),
                              );
                            },
                          ),
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: state.studyRooms.length,
                    ),
                  ),
                ),

              // Study Circles Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Study Circles (${state.studyCircles.length})',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) => AnimatedScale(
                          scale: isHovered ? 1.05 : 1,
                          duration: AppMotion.snappy,
                          curve: AppMotion.easeOutCubic,
                          child: ShrinkableButton(
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
                                        context.read<CommunityHubBloc>().add(
                                          CreateStudyCircleEvent(
                                            name: name,
                                            track: track,
                                            targetWeeklyMinutes:
                                                targetWeeklyMinutes,
                                          ),
                                        );
                                      },
                                ),
                              );
                            },
                            child: Text(
                              '+ Start Circle',
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (state.studyCircles.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Center(
                      child: Text(
                        'No study circles available yet.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final circle = state.studyCircles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StudyCircleCard(
                            circle: circle,
                            onJoinTap: () {
                              context.read<CommunityHubBloc>().add(
                                JoinStudyCircleEvent(circle.id),
                              );
                            },
                          ),
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: state.studyCircles.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeckMarketplaceTab extends StatelessWidget {
  const _DeckMarketplaceTab({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommunityHubBloc>().add(const LoadCommunityHubEvent());
      },
      color: colors.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_rounded,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Community Deck Marketplace',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (state.sharedDecks.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 48,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.style_outlined,
                            size: 44,
                            color: colors.textSecondary.withAlpha(120),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No community decks published yet.',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = state.sharedDecks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MarketplaceDeckCard(
                            deck: deck,
                            onCloneTap: () {
                              context.read<CommunityHubBloc>().add(
                                CloneDeckEvent(deck.id),
                              );
                            },
                            onTap: () {
                              unawaited(
                                context.router.push(
                                  DeckMarketplaceDetailRoute(deck: deck),
                                ),
                              );
                            },
                          ),
                        )
                            .animate(
                              delay: (index < 6 ? index * 45 : 0).ms,
                            )
                            .fadeIn(duration: 200.ms)
                            .slideY(
                              begin: 0.04,
                              end: 0,
                              curve: Curves.easeOutCubic,
                            );
                      },
                      childCount: state.sharedDecks.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
