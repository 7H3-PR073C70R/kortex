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
    final effectiveTrack = (targetTrack != null &&
            targetTrack.trim().isNotEmpty &&
            targetTrack != 'General')
        ? targetTrack.trim()
        : 'WAEC';

    final availableTracks = useMemoized(
      () => _getAvailableTracks(targetTrack),
      [targetTrack],
    );

    final hubState = context.watch<CommunityHubBloc>().state;
    final hasActiveFilters = hubState.selectedTrack != 'All' ||
        (hubState.selectedForumFilter != 'trending' &&
            hubState.selectedForumFilter.isNotEmpty);
    final activeFilterCount = (hubState.selectedTrack != 'All' ? 1 : 0) +
        (hubState.selectedForumFilter != 'trending' &&
                hubState.selectedForumFilter.isNotEmpty
            ? 1
            : 0);

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
          title: AnimatedSwitcher(
            duration: AppMotion.snappy,
            switchInCurve: AppMotion.easeOutCubic,
            switchOutCurve: AppMotion.easeOutCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: isSearchExpanded.value
                ? _buildSearchHeader(
                    context: context,
                    searchController: searchController,
                    searchQuery: searchQuery,
                    debounceTimer: debounceTimer,
                    isSearchExpanded: isSearchExpanded,
                    availableTracks: availableTracks,
                    effectiveTrack: effectiveTrack,
                    hasActiveFilters: hasActiveFilters,
                    activeFilterCount: activeFilterCount,
                  )
                : _buildStandardHeader(
                    context: context,
                    title: l10n.forumTab,
                    selectedTrack: hubState.selectedTrack,
                    selectedForumFilter: hubState.selectedForumFilter,
                    hasActiveFilters: hasActiveFilters,
                    activeFilterCount: activeFilterCount,
                    availableTracks: availableTracks,
                    effectiveTrack: effectiveTrack,
                  ),
          ),
          actions: isSearchExpanded.value
              ? null
              : [
                  // 1. Consolidated Dynamic Action Capsule (Search + Filter with Badge)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark
                            ? colors.surfaceSecondary
                            : colors.surfaceSecondary.withAlpha(140),
                        borderRadius: AppRadius.radiusSheet,
                        border: Border.all(
                          color: hasActiveFilters
                              ? colors.primary.withAlpha(isDark ? 80 : 50)
                              : colors.surfaceBorder.withAlpha(isDark ? 80 : 60),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Search Button
                          PlatformHoverBuilder(
                            builder: (context, isHovered, child) =>
                                AnimatedScale(
                              scale: isHovered ? 1.08 : 1.0,
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              child: child,
                            ),
                            child: ShrinkableButton(
                              onTap: () {
                                unawaited(HapticFeedback.lightImpact());
                                isSearchExpanded.value = true;
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.search_rounded,
                                  size: 19,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          // Subtle Hairline Divider
                          Container(
                            width: 1,
                            height: 18,
                            color: colors.surfaceBorder.withAlpha(isDark ? 90 : 70),
                          ),
                          // Filter Button with Badge
                          PlatformHoverBuilder(
                            builder: (context, isHovered, child) =>
                                AnimatedScale(
                              scale: isHovered ? 1.08 : 1.0,
                              duration: AppMotion.snappy,
                              curve: AppMotion.easeOutCubic,
                              child: child,
                            ),
                            child: ShrinkableButton(
                              onTap: () {
                                unawaited(HapticFeedback.lightImpact());
                                _showCommunityFilterSheet(
                                  context: context,
                                  availableTracks: availableTracks,
                                  effectiveTrack: effectiveTrack,
                                );
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                alignment: Alignment.center,
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 18,
                                      color: hasActiveFilters
                                          ? colors.primary
                                          : colors.textSecondary,
                                    ),
                                    if (hasActiveFilters && activeFilterCount > 0)
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: colors.primary,
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
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Primary Create Post Action Pill Button
                  Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) => AnimatedScale(
                        scale: isHovered ? 1.03 : 1.0,
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: child,
                      ),
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
                        child: Container(
                          height: 38,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: AppRadius.radiusSheet,
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withAlpha(isDark ? 60 : 35),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 18,
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
                ],
        ),
        body: Column(
          children: [

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
                        availableTracks: availableTracks,
                        effectiveTrack: effectiveTrack,
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

  Widget _buildStandardHeader({
    required BuildContext context,
    required String title,
    required String selectedTrack,
    required String selectedForumFilter,
    required bool hasActiveFilters,
    required int activeFilterCount,
    required List<String> availableTracks,
    required String effectiveTrack,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      key: const ValueKey('standard_header'),
      children: [
        Text(
          title,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        if (hasActiveFilters) ...[
          const SizedBox(width: 8),
          PlatformHoverBuilder(
            builder: (context, isHovered, child) => AnimatedScale(
              scale: isHovered ? 1.05 : 1.0,
              duration: AppMotion.snappy,
              curve: AppMotion.easeOutCubic,
              child: child,
            ),
            child: ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.lightImpact());
                _showCommunityFilterSheet(
                  context: context,
                  availableTracks: availableTracks,
                  effectiveTrack: effectiveTrack,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 45 : 25),
                  borderRadius: AppRadius.radiusBadge,
                  border: Border.all(
                    color: colors.primary.withAlpha(isDark ? 90 : 50),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selectedTrack != 'All'
                          ? Icons.school_rounded
                          : _getSortIcon(selectedForumFilter),
                      size: 13,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      selectedTrack != 'All'
                          ? selectedTrack
                          : _getSortLabel(selectedForumFilter),
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11.5,
                      ),
                    ),
                    if (activeFilterCount > 1) ...[
                      const SizedBox(width: 3),
                      Text(
                        '+${activeFilterCount - 1}',
                        style: typography.caption.bold.copyWith(
                          color: colors.primary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSearchHeader({
    required BuildContext context,
    required TextEditingController searchController,
    required ValueNotifier<String> searchQuery,
    required ObjectRef<Timer?> debounceTimer,
    required ValueNotifier<bool> isSearchExpanded,
    required List<String> availableTracks,
    required String effectiveTrack,
    required bool hasActiveFilters,
    required int activeFilterCount,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    return Row(
      key: const ValueKey('search_header'),
      children: [
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceSecondary.withAlpha(160),
              borderRadius: AppRadius.radiusSheet,
              border: Border.all(
                color: colors.primary.withAlpha(isDark ? 90 : 60),
                width: 1.2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
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
                    autofocus: true,
                    style: typography.subhead.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 13.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search discussions, topics, tags...',
                      hintStyle: typography.footnote.regular.copyWith(
                        color: colors.textSecondary.withAlpha(160),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      searchQuery.value = val;
                      debounceTimer.value?.cancel();
                      debounceTimer.value =
                          Timer(const Duration(milliseconds: 350), () {
                        context.read<CommunityHubBloc>().add(
                              SearchForumPostsEvent(val.trim()),
                            );
                      });
                    },
                  ),
                ),
                if (searchQuery.value.isNotEmpty)
                  ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      searchController.clear();
                      searchQuery.value = '';
                      context.read<CommunityHubBloc>().add(
                            const SearchForumPostsEvent(''),
                          );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    _showCommunityFilterSheet(
                      context: context,
                      availableTracks: availableTracks,
                      effectiveTrack: effectiveTrack,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 16,
                          color: hasActiveFilters
                              ? colors.primary
                              : colors.textSecondary,
                        ),
                        if (hasActiveFilters && activeFilterCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colors.primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            searchController.clear();
            searchQuery.value = '';
            context.read<CommunityHubBloc>().add(
                  const SearchForumPostsEvent(''),
                );
            isSearchExpanded.value = false;
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(
              'Cancel',
              style: typography.subhead.bold.copyWith(
                color: colors.primary,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ForumPostsList extends HookWidget {
  const _ForumPostsList({
    required this.state,
    required this.searchQuery,
    required this.availableTracks,
    required this.effectiveTrack,
  });

  final CommunityState state;
  final String searchQuery;
  final List<String> availableTracks;
  final String effectiveTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
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
}

// ---------------------------------------------------------------------------
// Consolidated Filter Models & Helpers
// ---------------------------------------------------------------------------

class _QuickSortItem {
  const _QuickSortItem(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

const List<_QuickSortItem> _kQuickSorts = [
  _QuickSortItem('trending', 'Trending', Icons.local_fire_department_rounded),
  _QuickSortItem('latest', 'Latest', Icons.schedule_rounded),
  _QuickSortItem('topToday', 'Top Today', Icons.military_tech_rounded),
  _QuickSortItem('questions', 'Questions', Icons.help_outline_rounded),
  _QuickSortItem('solved', 'Solved', Icons.check_circle_outline_rounded),
  _QuickSortItem('myPosts', 'My Posts', Icons.person_outline_rounded),
  _QuickSortItem('saved', 'Saved', Icons.bookmark_outline_rounded),
];

String _getSortLabel(String filter) {
  switch (filter.toLowerCase()) {
    case 'trending':
      return 'Trending';
    case 'latest':
      return 'Latest';
    case 'toptoday':
    case 'top_today':
      return 'Top Today';
    case 'questions':
      return 'Questions';
    case 'solved':
      return 'Solved';
    case 'myposts':
    case 'my_posts':
      return 'My Posts';
    case 'saved':
    case 'bookmarks':
      return 'Saved';
    default:
      return filter.isNotEmpty
          ? '${filter[0].toUpperCase()}${filter.substring(1)}'
          : 'Filter';
  }
}

IconData _getSortIcon(String filter) {
  switch (filter.toLowerCase()) {
    case 'trending':
      return Icons.local_fire_department_rounded;
    case 'latest':
      return Icons.schedule_rounded;
    case 'toptoday':
    case 'top_today':
      return Icons.military_tech_rounded;
    case 'questions':
      return Icons.help_outline_rounded;
    case 'solved':
      return Icons.check_circle_outline_rounded;
    case 'myposts':
    case 'my_posts':
      return Icons.person_outline_rounded;
    case 'saved':
    case 'bookmarks':
      return Icons.bookmark_outline_rounded;
    default:
      return Icons.tune_rounded;
  }
}

IconData getTrackIcon(String track) {
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
    case 'all':
      return Icons.public_rounded;
    default:
      return Icons.auto_stories_rounded;
  }
}

List<String> _getAvailableTracks(String? userTrack) {
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
}

void _showCommunityFilterSheet({
  required BuildContext context,
  required List<String> availableTracks,
  required String effectiveTrack,
}) {
  final bloc = context.read<CommunityHubBloc>();
  unawaited(
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor:
          context.colors.black.withAlpha(context.isDarkMode ? 170 : 110),
      builder: (sheetContext) => BlocProvider.value(
        value: bloc,
        child: _CommunityFilterBottomSheet(
          availableTracks: availableTracks,
          effectiveTrack: effectiveTrack,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Consolidated Filter Bottom Sheet
// ---------------------------------------------------------------------------

class _CommunityFilterBottomSheet extends HookWidget {
  const _CommunityFilterBottomSheet({
    required this.availableTracks,
    required this.effectiveTrack,
  });

  final List<String> availableTracks;
  final String effectiveTrack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final bloc = context.read<CommunityHubBloc>();

    final currentSelectedTrack = bloc.state.selectedTrack;
    final currentSelectedSort = bloc.state.selectedForumFilter;

    final tempTrack = useState<String>(currentSelectedTrack);
    final tempSort = useState<String>(currentSelectedSort);

    final isDefault = tempTrack.value == 'All' && tempSort.value == 'trending';

    final activeFilterCount = (tempTrack.value != 'All' ? 1 : 0) +
        (tempSort.value != 'trending' ? 1 : 0);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? colors.surfaceBorder.withAlpha(50)
                : colors.surfaceBorder.withAlpha(30),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Indicator Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 36,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceBorder.withAlpha(80)
                      : colors.surfaceBorder.withAlpha(60),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Sheet Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primary.withAlpha(isDark ? 40 : 25),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter & Sort',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Customize what appears in your community feed',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isDefault)
                    TextButton(
                      onPressed: () {
                        unawaited(HapticFeedback.lightImpact());
                        tempTrack.value = 'All';
                        tempSort.value = 'trending';
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Reset',
                        style: typography.caption.bold.copyWith(
                          color: colors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    ),
                    splashRadius: 18,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Scrollable Options Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Academic Focus / Track
                    Row(
                      children: [
                        Icon(
                          Icons.school_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Academic Track / Focus',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // "All Tracks" option
                        _buildFilterOptionChip(
                          context: context,
                          label: 'All Tracks',
                          icon: Icons.public_rounded,
                          isSelected: tempTrack.value == 'All',
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            tempTrack.value = 'All';
                          },
                        ),
                        // Available tracks list
                        ...availableTracks.map((track) {
                          final isSelected = tempTrack.value.toLowerCase() ==
                              track.toLowerCase();
                          final isHomeTrack = track.toLowerCase() ==
                              effectiveTrack.toLowerCase();
                          return _buildFilterOptionChip(
                            context: context,
                            label: track,
                            icon: getTrackIcon(track),
                            isSelected: isSelected,
                            isHighlighted: isHomeTrack && !isSelected,
                            highlightBadge: isHomeTrack,
                            onTap: () {
                              unawaited(HapticFeedback.selectionClick());
                              tempTrack.value = track;
                            },
                          );
                        }),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Feed Sort & Content Filter
                    Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'Feed Order & Content',
                          style: typography.caption.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _kQuickSorts.map((sortItem) {
                        final isSelected = tempSort.value == sortItem.key;
                        return _buildFilterOptionChip(
                          context: context,
                          label: sortItem.label,
                          icon: sortItem.icon,
                          isSelected: isSelected,
                          onTap: () {
                            unawaited(HapticFeedback.selectionClick());
                            tempSort.value = sortItem.key;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // Bottom Apply Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) => AnimatedScale(
                        scale: isHovered ? 1.02 : 1.0,
                        duration: AppMotion.snappy,
                        curve: AppMotion.easeOutCubic,
                        child: ShrinkableButton(
                          onTap: () {
                            unawaited(HapticFeedback.mediumImpact());
                            bloc
                              ..add(ChangeTrackFilterEvent(tempTrack.value))
                              ..add(ChangeForumSortFilterEvent(tempSort.value));
                            Navigator.of(context).pop();
                          },
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              borderRadius: AppRadius.radiusPanel,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primary.withAlpha(isDark ? 80 : 50),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    activeFilterCount > 0
                                        ? 'Apply Filters ($activeFilterCount)'
                                        : 'Apply Filters',
                                    style: typography.body.bold.copyWith(
                                      color: colors.white,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOptionChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isHighlighted = false,
    bool highlightBadge = false,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) => AnimatedScale(
        scale: isHovered ? 1.04 : 1.0,
        duration: AppMotion.snappy,
        curve: AppMotion.easeOutCubic,
        child: ShrinkableButton(
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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
                    : (isHighlighted
                        ? colors.syllabotAccent.withAlpha(isDark ? 120 : 90)
                        : (isHovered
                            ? colors.primary.withAlpha(isDark ? 70 : 50)
                            : colors.surfaceBorder
                                .withAlpha(isDark ? 40 : 25))),
                width: isSelected ? 1.4 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withAlpha(isDark ? 55 : 30),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
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
                    fontSize: 12.5,
                  ),
                ),
                if (highlightBadge) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? colors.white : colors.syllabotAccent,
                    ),
                  ),
                ],
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
