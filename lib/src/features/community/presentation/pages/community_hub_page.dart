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
import 'package:kortex/src/features/community/domain/entities/study_room_entity.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/pages/create_forum_discussion_page.dart';
import 'package:kortex/src/features/community/presentation/widgets/auto_community_banner_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_shimmer.dart';
import 'package:kortex/src/features/community/presentation/widgets/track_forum_post_card.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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

    final authState = context.watch<AuthBloc?>()?.state;
    final targetTrack = authState?.userProfile?.targetTrack;

    final isSearchExpanded = useState<bool>(false);
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);

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
      return () => debounceTimer.value?.cancel();
    }, const []);

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
          backgroundColor: isDark
              ? colors.backgroundPrimary
              : colors.surfacePrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleSpacing: 16,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.forumTab,
                style: typography.title2.bold.copyWith(
                  color: colors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          actions: [
            // Search Action Button
            PlatformHoverBuilder(
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.06 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    isSearchExpanded.value = !isSearchExpanded.value;
                    if (!isSearchExpanded.value) {
                      searchController.clear();
                      searchQuery.value = '';
                      debounceTimer.value?.cancel();
                      context.read<CommunityHubBloc>().add(
                        const SearchForumPostsEvent(''),
                      );
                    }
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSearchExpanded.value
                          ? colors.primary.withAlpha(isDark ? 50 : 30)
                          : (isHovered
                                ? colors.primary.withAlpha(isDark ? 30 : 20)
                                : (isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfaceSecondary.withAlpha(
                                          140,
                                        ))),
                    ),
                    child: Icon(
                      isSearchExpanded.value
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      size: 20,
                      color: isSearchExpanded.value
                          ? colors.primary
                          : colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Filter Action Button
            PlatformHoverBuilder(
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.06 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: ShrinkableButton(
                  onTap: () {
                  
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSearchExpanded.value
                          ? colors.primary.withAlpha(isDark ? 50 : 30)
                          : (isHovered
                                ? colors.primary.withAlpha(isDark ? 30 : 20)
                                : (isDark
                                      ? colors.surfaceSecondary
                                      : colors.surfaceSecondary.withAlpha(
                                          140,
                                        ))),
                    ),
                    child: Icon(
                      Icons.filter_1,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Notifications Action Button with unread badge
            PlatformHoverBuilder(
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.06 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    context.showSnackBar(
                      message: 'No unread forum notifications',
                    );
                  },
                  child: Stack(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isHovered
                              ? colors.primary.withAlpha(isDark ? 30 : 20)
                              : (isDark
                                    ? colors.surfaceSecondary
                                    : colors.surfaceSecondary.withAlpha(140)),
                        ),
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 20,
                          color: colors.textSecondary,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Create Post Action Pill Button
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: PlatformHoverBuilder(
                builder: (context, isHovered, child) => AnimatedScale(
                  scale: isHovered ? 1.03 : 1.0,
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  child: ShrinkableButton(
                    onTap: () async {
                      unawaited(HapticFeedback.lightImpact());
                      final hubBloc = context.read<CommunityHubBloc>();
                      final initialTrack =
                          targetTrack ?? hubBloc.state.selectedTrack;
                      final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                            value: hubBloc,
                            child: CreateForumDiscussionPage(
                              initialTrack: initialTrack.isNotEmpty
                                  ? initialTrack
                                  : 'WAEC',
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
                    child: AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7.5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: AppRadius.radiusPanel,
                        boxShadow: [
                          BoxShadow(
                            color: colors.black.withAlpha(
                              isHovered ? 50 : 20,
                            ),
                            blurRadius: isHovered ? 14 : 10,
                            offset: Offset(0, isHovered ? 4 : 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            size: 17,
                            color: colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Post',
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                              fontSize: 13,
                              letterSpacing: 0.2,
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
        ),
        body: Column(
          children: [
            // Collapsible Search Field with Fluid Animation
            AnimatedSize(
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              alignment: Alignment.topCenter,
              child: isSearchExpanded.value
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? colors.surfaceSecondary
                                  : colors.surfaceSecondary.withAlpha(120),
                              borderRadius: AppRadius.radiusCard,
                              border: Border.all(
                                color: colors.primary.withAlpha(
                                  isDark ? 60 : 40,
                                ),
                              ),
                            ),
                            child: TextField(
                              controller: searchController,
                              autofocus: true,
                              style: typography.body.regular.copyWith(
                                color: colors.textPrimary,
                              ),
                              onChanged: (val) {
                                searchQuery.value = val.trim();
                                debounceTimer.value?.cancel();
                                debounceTimer.value = Timer(
                                  const Duration(milliseconds: 350),
                                  () {
                                    context.read<CommunityHubBloc>().add(
                                      SearchForumPostsEvent(val.trim()),
                                    );
                                  },
                                );
                              },
                              decoration: InputDecoration(
                                hintText: 'Search forum threads & topics...',
                                hintStyle: typography.body.regular.copyWith(
                                  color: colors.textSecondary,
                                ),
                                border: InputBorder.none,
                                icon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: colors.textSecondary,
                                ),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.clear_rounded,
                                          size: 18,
                                        ),
                                        onPressed: () {
                                          searchController.clear();
                                          searchQuery.value = '';
                                          debounceTimer.value?.cancel();
                                          context.read<CommunityHubBloc>().add(
                                            const SearchForumPostsEvent(''),
                                          );
                                        },
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Auto-Community Spinoff Banner (Appears when community is provisioned)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: AutoCommunityBannerWidget(
                  onTapOpenHub: (community) {
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
                    unawaited(
                      context.router.push(LiveStudyRoomRoute(room: room)),
                    );
                  },
                ),
              ),
            ),

            // Forum Posts Feed
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: BlocBuilder<CommunityHubBloc, CommunityState>(
                    builder: (context, state) {
                      if (state.status == CommunityStatus.loading &&
                          state.forumPosts.isEmpty) {
                        return const CommunityHubShimmer(tabIndex: 1);
                      }

                      return _ForumPostsList(
                        state: state,
                        searchQuery: searchQuery.value,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForumPostsList extends HookWidget {
  const _ForumPostsList({
    required this.state,
    required this.searchQuery,
  });

  final CommunityState state;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final scrollController = useScrollController();
    final isPulseBannerDismissed = useState<bool>(false);

    final authState = context.watch<AuthBloc?>()?.state;
    final userTrack = authState?.userProfile?.targetTrack;
    final effectiveTrack =
        (userTrack != null &&
            userTrack.trim().isNotEmpty &&
            userTrack != 'General')
        ? userTrack.trim()
        : 'WAEC';

    final isInitialTrackApplied = useRef(false);
    useEffect(() {
      if (!isInitialTrackApplied.value && effectiveTrack.isNotEmpty) {
        isInitialTrackApplied.value = true;
        if (state.selectedTrack == 'All') {
          context.read<CommunityHubBloc>().add(
            ChangeTrackFilterEvent(effectiveTrack),
          );
        }
      }
      return null;
    }, [effectiveTrack]);

    final availableTracks = useMemoized(() {
      final base = <String>[
        'WAEC',
        'JAMB',
        'Mathematics',
        'Physics',
        'Chemistry',
        'Computer Science',
        'Medicine',
        'SAT',
      ];
      if (userTrack != null &&
          userTrack.trim().isNotEmpty &&
          userTrack != 'General' &&
          !base.contains(userTrack.trim())) {
        base.insert(0, userTrack.trim());
      }
      return base;
    }, [userTrack]);

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
          // 1. Academic Track Selection Filter
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  _buildTrackChip(
                    context: context,
                    label: 'All Tracks',
                    icon: Icons.public_rounded,
                    isSelected: state.selectedTrack == 'All',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeTrackFilterEvent('All'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  ...availableTracks.map((trk) {
                    final isUserHomeTrack = trk == effectiveTrack;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildTrackChip(
                        context: context,
                        label: trk,
                        icon: _getTrackIcon(trk),
                        isSelected: state.selectedTrack == trk,
                        isHomeTrack: isUserHomeTrack,
                        onTap: () {
                          unawaited(HapticFeedback.selectionClick());
                          context.read<CommunityHubBloc>().add(
                            ChangeTrackFilterEvent(trk),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // 2. Interactive Sticky Sort Filter Bar
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 1. Trending Filter
                  _buildFilterChip(
                    context: context,
                    label: 'Trending',
                    icon: Icons.local_fire_department_rounded,
                    isSelected: state.selectedForumFilter == 'trending',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('trending'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 2. Latest Filter
                  _buildFilterChip(
                    context: context,
                    label: 'Latest',
                    icon: Icons.schedule_rounded,
                    isSelected: state.selectedForumFilter == 'latest',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('latest'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 3. Top Today
                  _buildFilterChip(
                    context: context,
                    label: 'Top Today',
                    icon: Icons.military_tech_rounded,
                    isSelected:
                        state.selectedForumFilter == 'topToday' ||
                        state.selectedForumFilter == 'top_today',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('topToday'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 4. Questions Only
                  _buildFilterChip(
                    context: context,
                    label: 'Questions',
                    icon: Icons.help_outline_rounded,
                    isSelected: state.selectedForumFilter == 'questions',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('questions'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 5. Solved
                  _buildFilterChip(
                    context: context,
                    label: 'Solved',
                    icon: Icons.check_circle_outline_rounded,
                    isSelected: state.selectedForumFilter == 'solved',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('solved'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 6. My Posts
                  _buildFilterChip(
                    context: context,
                    label: 'My Posts',
                    icon: Icons.person_outline_rounded,
                    isSelected:
                        state.selectedForumFilter == 'myPosts' ||
                        state.selectedForumFilter == 'my_posts',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('myPosts'),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 7. Saved / Bookmarks
                  _buildFilterChip(
                    context: context,
                    label: 'Saved',
                    icon: Icons.bookmark_outline_rounded,
                    isSelected:
                        state.selectedForumFilter == 'saved' ||
                        state.selectedForumFilter == 'bookmarks',
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      context.read<CommunityHubBloc>().add(
                        const ChangeForumSortFilterEvent('saved'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Ambient Community Pulse Banner
          if (!isPulseBannerDismissed.value)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? colors.surfaceSecondary
                        : colors.surfaceSecondary.withAlpha(160),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withAlpha(isDark ? 35 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 20 : 5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Ambient Glowing Orb
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.primary.withAlpha(isDark ? 25 : 15),
                          ),
                        ),
                      ),

                      // Banner Content
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            // Insights Pulse Icon with live indicator dot
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colors.primary.withAlpha(
                                      isDark ? 40 : 25,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.insights_rounded,
                                    size: 18,
                                    color: colors.primary,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.success,
                                      border: Border.all(
                                        color: isDark
                                            ? colors.surfaceSecondary
                                            : colors.surfacePrimary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),

                            // Text Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'COMMUNITY PULSE',
                                    style: typography.caption.bold.copyWith(
                                      color: colors.primary,
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  RichText(
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '1,420 scholars ',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.primary,
                                                fontSize: 12.5,
                                              ),
                                        ),
                                        TextSpan(
                                          text:
                                              'discussing ${state.selectedTrack == 'All' ? 'community' : state.selectedTrack} syllabus shifts',
                                          style: typography.caption.medium
                                              .copyWith(
                                                color: colors.textPrimary,
                                                fontSize: 12,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Dismiss Button
                            ShrinkableButton(
                              onTap: () {
                                unawaited(HapticFeedback.lightImpact());
                                isPulseBannerDismissed.value = true;
                              },
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colors.textSecondary.withAlpha(
                                    isDark ? 40 : 25,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Posts Feed or Empty State
          if (filteredPosts.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 48,
                ),
                child: Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withAlpha(isDark ? 30 : 15),
                        ),
                        child: Icon(
                          searchQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.forum_outlined,
                          size: 40,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        searchQuery.isNotEmpty
                            ? 'No Matching Discussions'
                            : 'No Discussions Yet',
                        style: typography.headline.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        searchQuery.isNotEmpty
                            ? 'No threads found for "$searchQuery". Try searching a different keyword or topic tag.'
                            : (state.selectedTrack == 'All'
                                  ? 'No discussions have been posted in the community yet. Be the first to start a conversation!'
                                  : 'Be the first scholar in ${state.selectedTrack} to ask a question or start a discussion.'),
                        textAlign: TextAlign.center,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (searchQuery.isNotEmpty)
                        ShrinkableButton(
                          onTap: () {
                            context.read<CommunityHubBloc>().add(
                              const SearchForumPostsEvent(''),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(isDark ? 40 : 25),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.primary.withAlpha(80),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: colors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Clear Search',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ShrinkableButton(
                              onTap: () async {
                                final hubBloc = context
                                    .read<CommunityHubBloc>();
                                final created = await Navigator.of(context)
                                    .push<bool>(
                                      MaterialPageRoute(
                                        builder: (_) => BlocProvider.value(
                                          value: hubBloc,
                                          child: CreateForumDiscussionPage(
                                            initialTrack:
                                                state.selectedTrack == 'All'
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.black.withAlpha(
                                        isDark ? 50 : 20,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.add_rounded,
                                      size: 18,
                                      color: colors.white,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Start a Discussion',
                                      style: typography.caption.bold.copyWith(
                                        color: colors.white,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (state.selectedTrack != 'All') ...[
                              const SizedBox(height: 12),
                              ShrinkableButton(
                                onTap: () {
                                  unawaited(HapticFeedback.selectionClick());
                                  context.read<CommunityHubBloc>().add(
                                    const ChangeTrackFilterEvent('All'),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? colors.surfaceSecondary
                                        : colors.surfaceSecondary.withAlpha(
                                            120,
                                          ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: colors.surfaceBorder.withAlpha(
                                        isDark ? 40 : 25,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.public_rounded,
                                        size: 15,
                                        color: colors.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Explore All Community Discussions',
                                        style: typography.caption.medium
                                            .copyWith(
                                              color: colors.textSecondary,
                                              fontSize: 12,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),
                ),
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

  IconData _getTrackIcon(String track) {
    switch (track.toLowerCase()) {
      case 'waec':
        return Icons.school_rounded;
      case 'jamb':
        return Icons.menu_book_rounded;
      case 'mathematics':
        return Icons.calculate_rounded;
      case 'physics':
        return Icons.bolt_rounded;
      case 'chemistry':
        return Icons.science_rounded;
      case 'computer science':
        return Icons.terminal_rounded;
      case 'medicine':
        return Icons.health_and_safety_rounded;
      case 'sat':
        return Icons.edit_note_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  Widget _buildTrackChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isHomeTrack = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.05 : 1.0,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary.withAlpha(
                      isDark ? (isHovered ? 80 : 60) : (isHovered ? 55 : 40),
                    )
                  : (isHovered
                        ? colors.primary.withAlpha(isDark ? 30 : 20)
                        : (isDark
                              ? colors.surfaceSecondary.withAlpha(160)
                              : colors.surfaceSecondary.withAlpha(90))),
              borderRadius: AppRadius.radiusBadge,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : (isHovered
                          ? colors.primary.withAlpha(isDark ? 70 : 50)
                          : colors.surfaceBorder.withAlpha(isDark ? 40 : 25)),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? colors.primary : colors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.primary : colors.textPrimary,
                    fontSize: 11.5,
                  ),
                ),
                if (isHomeTrack) ...[
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? colors.primary
                          : colors.syllabotAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.05 : 1.0,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected
                  ? colors.primary
                  : (isHovered
                        ? colors.primary.withAlpha(isDark ? 30 : 20)
                        : (isDark
                              ? colors.surfaceSecondary
                              : colors.surfaceSecondary.withAlpha(120))),
              borderRadius: AppRadius.radiusPanel,
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : (isHovered
                          ? colors.primary.withAlpha(isDark ? 70 : 50)
                          : colors.surfaceBorder.withAlpha(isDark ? 30 : 20)),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isHovered ? (isDark ? 50 : 20) : (isDark ? 30 : 10),
                        ),
                        blurRadius: isHovered ? 12 : 8,
                        offset: Offset(0, isHovered ? 3 : 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? colors.white : colors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: typography.caption.bold.copyWith(
                    color: isSelected ? colors.white : colors.textPrimary,
                    fontSize: 12,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
