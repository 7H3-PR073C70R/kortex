import 'dart:async';
import 'dart:math' as math;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/auto_community_banner_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_shimmer.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_post_bottom_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_study_circle_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/create_study_room_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/live_focus_room_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/marketplace_deck_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/publish_deck_modal_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/streak_leaderboard_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/study_circle_card.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

@RoutePage()
class CommunityHubPage extends HookWidget {
  const CommunityHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CommunityHubBloc>(
          create: (_) =>
              locator<CommunityHubBloc>()..add(const LoadCommunityHubEvent()),
        ),
        BlocProvider<AutoCommunityCubit>.value(
          value: locator<AutoCommunityCubit>(),
        ),
      ],
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
    useListenable(tabController);

    final authState = context.watch<AuthBloc?>()?.state;
    final targetTrack = authState?.userProfile?.targetTrack;
    final liveFreezes = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>().getStreakFreezes()
        : 0;
    final effectiveStreakFreezes = math.max(
      authState?.userProfile?.streakFreezeCount ?? 0,
      liveFreezes,
    );

    // Auto provision / join community for user's academic track on launch & lock forum
    useEffect(() {
      if (targetTrack != null && targetTrack.trim().isNotEmpty) {
        unawaited(
          context.read<AutoCommunityCubit>().provisionForTrack(targetTrack),
        );
        context.read<CommunityHubBloc>().add(
          ChangeTrackFilterEvent(targetTrack),
        );
      }
      return null;
    }, [targetTrack]);

    useEffect(() {
      void listener() {
        context.read<CommunityHubBloc>().add(
          SwitchCommunityTabEvent(tabController.index),
        );
      }

      tabController.addListener(listener);
      return () => tabController.removeListener(listener);
    }, [tabController]);

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.communityTitle,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                unawaited(
                  CreatePostBottomSheet.show(
                    context,
                    lockedTrack: targetTrack,
                    onSubmit: ({
                      required title,
                      required content,
                      required track,
                      latexContent,
                      isQuestion = false,
                      syllabusTag = 'General',
                      isAnonymous = false,
                    }) {
                      context.read<CommunityHubBloc>().add(
                        CreateForumPostEvent(
                          title: title,
                          content: content,
                          track: track,
                          latexContent: latexContent,
                          isQuestion: isQuestion,
                          syllabusTag: syllabusTag,
                          isAnonymous: isAnonymous,
                        ),
                      );
                    },
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      colors.primary.withAlpha(220),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(isDark ? 80 : 50),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_note_rounded,
                      color: colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.createPostButton,
                      style: typography.caption.bold.copyWith(
                        color: colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppLiquidGlassTabBar(
              tabs: [
                l10n.liveRoomsTab,
                l10n.forumTab,
                l10n.marketplaceTab,
                l10n.leaderboardTab,
              ],
              selectedIndex: tabController.index,
              onTabSelected: (index) {
                tabController.animateTo(index);
                context.read<CommunityHubBloc>().add(
                  SwitchCommunityTabEvent(index),
                );
              },
              isCompact: true,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
              // Auto-Community Spinoff Banner (Appears when community is provisioned)
              AutoCommunityBannerWidget(
                onTapOpenHub: (community) {
                  tabController.animateTo(1);
                  context.read<CommunityHubBloc>().add(
                    ChangeTrackFilterEvent(community.courseCode),
                  );
                },
                onTapJoinRoom: (roomId) {
                  final hubState = context.read<CommunityHubBloc>().state;
                  final room = hubState.studyRooms.firstWhere(
                    (r) => r.id == roomId,
                    orElse: () => StudyRoomEntity(
                      id: roomId,
                      title: 'Focus Room',
                      subject: 'General Study',
                    ),
                  );
                  unawaited(context.router.push(LiveStudyRoomRoute(room: room)));
                },
              ),

              // Main Tab Content with Shimmer Skeleton
              Expanded(
                child: BlocConsumer<CommunityHubBloc, CommunityState>(
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
                        state.forumPosts.isEmpty) {
                      return CommunityHubShimmer(
                        tabIndex: tabController.index,
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
                                        streakFreezeCount: effectiveStreakFreezes,
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
                                      streakFreezeCount:
                                          effectiveStreakFreezes,
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
                                streakFreezeCount: effectiveStreakFreezes,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
    );
  }
}

class _LiveRoomsList extends StatelessWidget {
  const _LiveRoomsList({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ⚡ 1-Tap Instant Study Double Pairing Card
        _InstantStudyDoubleCard(
          state: state,
          onMatch: (matchedRoom) {
            unawaited(context.router.push(LiveStudyRoomRoute(room: matchedRoom)));
          },
        ),
        const SizedBox(height: 14),

        // Study Circles (Micro-Accountability Pods of 3-6) Section
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.syllabotAccent.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 16,
                      color: colors.syllabotAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Study Circles (3-6 Pods)',
                    style: typography.subhead.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              ShrinkableButton(
                onTap: () {
                  unawaited(
                    CreateStudyCircleSheet.show(
                      context,
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
                      },
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.syllabotAccent.withAlpha(isDark ? 45 : 25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: colors.syllabotAccent.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: colors.syllabotAccent),
                      const SizedBox(width: 4),
                      Text(
                        'New Pod',
                        style: typography.caption.bold.copyWith(
                          color: colors.syllabotAccent,
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
        if (state.studyCircles.isEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary.withAlpha(120) : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 25 : 15),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: colors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Join a 3-6 student pod to share weekly study targets and keep each other accountable.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...state.studyCircles.map((circle) {
            return StudyCircleCard(
              circle: circle,
              onJoinTap: () {
                context.read<CommunityHubBloc>().add(
                  JoinStudyCircleEvent(circle.id),
                );
                context.showSnackBar(
                  message: 'Joined ${circle.name}!',
                );
              },
            );
          }),
        const SizedBox(height: 8),

        // Action Header: Room Count + Launch Room Button
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 40 : 25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.headphones_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Silent Focus Cockpits (${state.studyRooms.length})',
                    style: typography.subhead.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              ShrinkableButton(
                onTap: () {
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
                    color: colors.primary.withAlpha(isDark ? 50 : 30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 80 : 50),
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
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Room Cards or Empty State
        if (state.studyRooms.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 30 : 20),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 48,
                  color: colors.primary.withAlpha(120),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.noActiveRooms,
                  style: typography.headline.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.launchRoomSubtitle,
                  textAlign: TextAlign.center,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ShrinkableButton(
                  onTap: () {
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
                        },
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.launchFocusRoom,
                      style: typography.footnote.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...state.studyRooms.map((room) {
            return LiveFocusRoomCard(
              room: room,
              onJoinTap: () {
                unawaited(context.router.push(LiveStudyRoomRoute(room: room)));
              },
            );
          }),
      ],
    );
  }
}

class _ForumPostsList extends HookWidget {
  const _ForumPostsList({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final authState = context.watch<AuthBloc?>()?.state;
    final userTrack = authState?.userProfile?.targetTrack;
    final effectiveTrack = (userTrack != null && userTrack.trim().isNotEmpty && userTrack != 'General')
        ? userTrack.trim()
        : 'WAEC';

    useEffect(() {
      if (state.selectedTrack != effectiveTrack) {
        context.read<CommunityHubBloc>().add(
          ChangeTrackFilterEvent(effectiveTrack),
        );
      }
      return null;
    }, [effectiveTrack]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Track Forum Header Scoped exclusively to active track
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(isDark ? 30 : 15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 50 : 25),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 50 : 25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.school_rounded,
                  color: colors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$effectiveTrack Forum',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ACTIVE TRACK',
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Discussions & questions calibrated to your curriculum',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Questions Only Bounty Filter Toggle Bar
        ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            context.read<CommunityHubBloc>().add(
              ToggleQuestionsOnlyFilterEvent(questionsOnly: !state.questionsOnly),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: state.questionsOnly
                  ? colors.warning.withAlpha(isDark ? 45 : 25)
                  : (isDark ? colors.surfaceSecondary : colors.surfacePrimary),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: state.questionsOnly
                    ? colors.warning
                    : colors.primary.withAlpha(isDark ? 30 : 15),
                width: state.questionsOnly ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  state.questionsOnly ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                  size: 18,
                  color: state.questionsOnly ? colors.warning : colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Peer Question Bounties (+100 XP)',
                    style: typography.caption.bold.copyWith(
                      color: state.questionsOnly ? colors.warning : colors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (state.questionsOnly ? colors.warning : colors.primary)
                        .withAlpha(isDark ? 40 : 20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.questionsOnly ? 'Active' : 'Show Only',
                    style: typography.caption.bold.copyWith(
                      fontSize: 10,
                      color: state.questionsOnly ? colors.warning : colors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Forum Post Cards or Empty State
        if (state.forumPosts.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 30 : 20),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: 48,
                  color: colors.primary.withAlpha(120),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.noForumDiscussions,
                  style: typography.headline.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.startQuestionSubtitle,
                  textAlign: TextAlign.center,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ...state.forumPosts.map((post) {
            return TrackForumPostCard(
              post: post,
              onTap: () {
                unawaited(context.router.push(ForumThreadDetailRoute(post: post)));
              },
            );
          }),
      ],
    );
  }
}

class _MarketplaceDecksList extends StatelessWidget {
  const _MarketplaceDecksList({required this.state});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // Action Header: Shared Decks count + Share Deck Button
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.communitySharedDecks(state.sharedDecks.length),
                style: typography.footnote.bold.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              ShrinkableButton(
                onTap: () {
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
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(isDark ? 50 : 30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 80 : 50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.share_rounded,
                        color: colors.primary,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.shareDeckAction,
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Deck Cards or Empty State
        if (state.sharedDecks.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 30 : 20),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.style_outlined,
                  size: 48,
                  color: colors.primary.withAlpha(120),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.noDecksAvailable,
                  style: typography.headline.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.publishDecksSubtitle,
                  textAlign: TextAlign.center,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                ShrinkableButton(
                  onTap: () {
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
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.shareFirstDeck,
                      style: typography.footnote.bold.copyWith(
                        color: colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...state.sharedDecks.map((deck) {
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
          }),
      ],
    );
  }
}

class _InstantStudyDoubleCard extends StatelessWidget {
  const _InstantStudyDoubleCard({
    required this.state,
    required this.onMatch,
  });

  final CommunityState state;
  final ValueChanged<StudyRoomEntity> onMatch;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withAlpha(isDark ? 55 : 30),
            colors.syllabotAccent.withAlpha(isDark ? 35 : 18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 80 : 45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(isDark ? 30 : 15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 60 : 35),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instant Study Double',
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Jump into focus immediately with peers or Syllabot AI buddy',
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.mediumImpact());
              final targetTrack = context.read<AuthBloc?>()?.state.userProfile?.targetTrack;

              StudyRoomEntity? match;
              try {
                match = state.studyRooms.firstWhere(
                  (r) => r.activeParticipantsCount > 0 &&
                      (targetTrack == null || r.category == targetTrack || r.subject == targetTrack),
                );
              } on Object catch (_) {
                try {
                  match = state.studyRooms.firstWhere(
                    (r) => r.activeParticipantsCount > 0,
                  );
                } on Object catch (_) {
                  match = state.studyRooms.isNotEmpty
                      ? state.studyRooms.first
                      : StudyRoomEntity(
                          id: 'instant_focus_room',
                          title: '${targetTrack ?? "General"} Instant Focus Room',
                          subject: targetTrack ?? 'General Study',
                          category: targetTrack ?? 'General',
                        );
                }
              }

              onMatch(match);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.primary.withAlpha(210)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withAlpha(isDark ? 90 : 60),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Match Me Now (25m Focus)',
                    style: typography.caption.bold.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.3,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
