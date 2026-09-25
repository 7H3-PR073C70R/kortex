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
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_circle_detail_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
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

    final tabController = useTabController(initialLength: 3);
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
                                      context.showSnackBar(
                                        message:
                                            '✨ Launching Live Focus Room "$title"...',
                                        type: SnackBarType.success,
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
                  : (tabController.index == 1
                      ? PlatformHoverBuilder(
                          builder: (context, isHovered, child) => AnimatedScale(
                            scale: isHovered ? 1.03 : 1,
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
                                          context.showSnackBar(
                                            message:
                                                '🎉 Study Circle "$name" created successfully!',
                                            type: SnackBarType.success,
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
                                      ? colors.primary.withAlpha(
                                          isDark ? 65 : 45,
                                        )
                                      : colors.primary.withAlpha(
                                          isDark ? 40 : 25,
                                        ),
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
                                      Icons.groups_rounded,
                                      color: colors.primary,
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Start Circle',
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
                                      ? colors.primary.withAlpha(
                                          isDark ? 65 : 45,
                                        )
                                      : colors.primary.withAlpha(
                                          isDark ? 40 : 25,
                                        ),
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
                        )),
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
                    key: AppTourKeys.pomodoroCardKey,
                    tabs: [
                      l10n.liveRoomsTab,
                      'Study Circles',
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
                // 1. Live Focus Rooms
                _LiveRoomsTab(
                  key: AppTourKeys.liveRoomsCardKey,
                  state: state,
                  targetTrack: targetTrack,
                ),

                // 2. Study Circles
                _StudyCirclesTab(
                  state: state,
                  targetTrack: targetTrack,
                ),

                // 3. Deck Marketplace
                _DeckMarketplaceTab(
                  key: AppTourKeys.marketplaceCardKey,
                  state: state,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LiveRoomsTab extends StatefulWidget {
  const _LiveRoomsTab({
    required this.state,
    required this.targetTrack,
    super.key,
  });

  final CommunityState state;
  final String? targetTrack;

  @override
  State<_LiveRoomsTab> createState() => _LiveRoomsTabState();
}

class _LiveRoomsTabState extends State<_LiveRoomsTab> {
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = (widget.targetTrack != null && widget.targetTrack!.trim().isNotEmpty)
        ? widget.targetTrack!.trim()
        : 'All';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final userTrack = widget.targetTrack?.trim();

    final filteredRooms = widget.state.studyRooms.where((room) {
      if (_selectedFilter == 'All') return true;
      final filter = _selectedFilter.toLowerCase();
      final title = room.title.toLowerCase();
      final subject = room.subject.toLowerCase();
      final category = room.category.toLowerCase();
      return title.contains(filter) || subject.contains(filter) || category.contains(filter);
    }).toList();

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
              // Live Pomodoro Rooms Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
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
                        '${filteredRooms.length} active',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Track Filter Chips Bar (Clean 2-Chip Toggle: My Track vs All Tracks)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Row(
                    children: [
                      if (userTrack != null && userTrack.isNotEmpty) ...[
                        _buildFilterChip(
                          label: '🎯 My Track ($userTrack)',
                          isSelected: _selectedFilter.toLowerCase() == userTrack.toLowerCase(),
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            setState(() {
                              _selectedFilter = userTrack;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildFilterChip(
                        label: '🌐 All Tracks',
                        isSelected: _selectedFilter == 'All',
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          setState(() {
                            _selectedFilter = 'All';
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredRooms.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
                    child: Container(
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
                            _selectedFilter == 'All'
                                ? l10n.noActiveRooms
                                : 'No active focus rooms for "$_selectedFilter"',
                            style: typography.subhead.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedFilter == 'All'
                                ? 'Launch a new room to start studying with peers.'
                                : 'Be the first scholar in your $_selectedFilter track to start a Silent Focus Room! Peers in your track will be notified.',
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
                                  final activeTrackName = _selectedFilter == 'All'
                                      ? (userTrack ?? 'General')
                                      : _selectedFilter;
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
                                        'Launch $_selectedFilter Room',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_selectedFilter != 'All')
                                OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _selectedFilter = 'All';
                                    });
                                  },
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
                                  child: const Text('View All Tracks'),
                                ),
                            ],
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
                        final room = filteredRooms[index];
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
                      childCount: filteredRooms.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary.withAlpha(isDark ? 60 : 35)
              : colors.surfacePrimary,
          borderRadius: AppRadius.radiusBadge,
          border: Border.all(
            color: isSelected
                ? colors.primary
                : colors.surfaceBorder.withAlpha(isDark ? 50 : 35),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: typography.caption.medium.copyWith(
            color: isSelected ? colors.primary : colors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _StudyCirclesTab extends StatelessWidget {
  const _StudyCirclesTab({
    required this.state,
    required this.targetTrack,
  });

  final CommunityState state;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final isDark = context.isDarkMode;

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
              // Study Circles Onboarding Explainer Banner
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 28 : 14),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: colors.primary.withAlpha(isDark ? 45 : 25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.groups_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'What are Study Circles?',
                              style: typography.subhead.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Study Circles (Pods) are small peer study groups of up to 6 scholars taking the same track. Join a pod to commit to a collective weekly focus target, monitor contributions, and send instant nudges to keep each other accountable.',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildFeatureChip(
                              context,
                              Icons.people_outline_rounded,
                              'Max 6 Scholars',
                            ),
                            _buildFeatureChip(
                              context,
                              Icons.timer_outlined,
                              'Weekly Quests',
                            ),
                            _buildFeatureChip(
                              context,
                              Icons.bolt_rounded,
                              'Instant Nudges',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Study Circles Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.diversity_3_rounded,
                        size: 20,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Peer Study Circles',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${state.studyCircles.length} Pods',
                        style: typography.caption.medium.copyWith(
                          color: colors.textSecondary,
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
                      vertical: 48,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.groups_outlined,
                            size: 44,
                            color: colors.textSecondary.withAlpha(120),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'No study circles available yet.',
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
                        final circle = state.studyCircles[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: StudyCircleCard(
                            circle: circle,
                            onTapDetails: () {
                              unawaited(
                                StudyCircleDetailSheet.show(context, circle),
                              );
                            },
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

  Widget _buildFeatureChip(BuildContext context, IconData icon, String label) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfacePrimary,
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 30 : 15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: colors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: typography.caption.bold.copyWith(
              color: colors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckMarketplaceTab extends HookWidget {
  const _DeckMarketplaceTab({required this.state, super.key});

  final CommunityState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final selectedCategory = useState<String>('All');
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();

    const categories = [
      'All',
      'WAEC',
      'JAMB',
      'SAT',
      'STEM',
      'University',
    ];

    final filteredDecks = useMemoized(() {
      return state.sharedDecks.where((deck) {
        final matchesCat = selectedCategory.value == 'All' ||
            deck.category.toLowerCase() == selectedCategory.value.toLowerCase() ||
            deck.syllabusTag.toLowerCase().contains(selectedCategory.value.toLowerCase());
        final query = searchQuery.value.trim().toLowerCase();
        final matchesSearch = query.isEmpty ||
            deck.title.toLowerCase().contains(query) ||
            deck.subject.toLowerCase().contains(query) ||
            (deck.description?.toLowerCase().contains(query) ?? false);
        return matchesCat && matchesSearch;
      }).toList();
    }, [state.sharedDecks, selectedCategory.value, searchQuery.value]);

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
              // Header & Search Filter Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 20,
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
                          Text(
                            '${filteredDecks.length} Decks',
                            style: typography.caption.medium.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Search Input
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? colors.surfaceSecondary
                              : colors.surfaceSecondary.withAlpha(140),
                          borderRadius: AppRadius.radiusSheet,
                          border: Border.all(
                            color: colors.primary.withAlpha(isDark ? 60 : 35),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: searchController,
                                style: typography.caption.bold.copyWith(
                                  color: colors.textPrimary,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search decks, subjects, syllabus tags...',
                                  hintStyle: typography.caption.regular.copyWith(
                                    color: colors.textSecondary.withAlpha(160),
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) {
                                  searchQuery.value = val;
                                },
                              ),
                            ),
                            if (searchQuery.value.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  searchController.clear();
                                  searchQuery.value = '';
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Category Filter Pills
                      SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = selectedCategory.value == cat;
                            return PlatformHoverBuilder(
                              builder: (context, isHovered, child) =>
                                  ShrinkableButton(
                                onTap: () {
                                  unawaited(HapticFeedback.lightImpact());
                                  selectedCategory.value = cat;
                                },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? colors.primary
                                        : (isHovered
                                              ? colors.primary.withAlpha(
                                                  isDark ? 50 : 30,
                                                )
                                              : (isDark
                                                    ? colors.surfaceSecondary
                                                    : colors.surfaceSecondary
                                                        .withAlpha(160))),
                                    borderRadius: AppRadius.radiusBadge,
                                    border: Border.all(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.primary.withAlpha(
                                              isDark ? 40 : 20,
                                            ),
                                    ),
                                  ),
                                  child: Text(
                                    cat,
                                    style: typography.caption.bold.copyWith(
                                      color: isSelected
                                          ? colors.white
                                          : colors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (filteredDecks.isEmpty)
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
                            searchQuery.value.isNotEmpty
                                ? 'No decks found matching "${searchQuery.value}".'
                                : 'No community decks published yet.',
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = filteredDecks[index];
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
                      childCount: filteredDecks.length,
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
