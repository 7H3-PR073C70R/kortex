import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/pages/create_forum_discussion_page.dart';
import 'package:kortex/src/features/community/presentation/widgets/auto_community_banner_widget.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_filter_bottom_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_forum_feed_list.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_headers.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_shimmer.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/study_rooms/domain/entities/study_room_entity.dart';
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
        BlocProvider<NotificationsCubit>.value(
          value: locator.isRegistered<NotificationsCubit>()
              ? locator<NotificationsCubit>()
              : NotificationsCubit(),
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
      () => getAvailableTracks(targetTrack),
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
          automaticallyImplyLeading: false,
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
                ? CommunitySearchHeader(
                    searchController: searchController,
                    searchQuery: searchQuery,
                    debounceTimer: debounceTimer,
                    isSearchExpanded: isSearchExpanded,
                    availableTracks: availableTracks,
                    effectiveTrack: effectiveTrack,
                    hasActiveFilters: hasActiveFilters,
                    activeFilterCount: activeFilterCount,
                  )
                : CommunityStandardHeader(
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
                  // 1. Notification Shortcut Button with unread indicator
                  const _CommunityNotificationAction(),
                  const SizedBox(width: 8),

                  // 2. Consolidated Dynamic Action Capsule (Search + Filter with Badge)
                  _CommunitySearchFilterCapsule(
                    hasActiveFilters: hasActiveFilters,
                    activeFilterCount: activeFilterCount,
                    isDark: isDark,
                    onOpenSearch: () {
                      isSearchExpanded.value = true;
                    },
                    onOpenFilter: () {
                      showCommunityFilterSheet(
                        context: context,
                        availableTracks: availableTracks,
                        effectiveTrack: effectiveTrack,
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 3. Primary Create Post Action Pill Button
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

                      return CommunityForumFeedList(
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
}

class _CommunityNotificationAction extends StatelessWidget {
  const _CommunityNotificationAction();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;

    final unreadCount = context.select<NotificationsCubit, int>(
      (cubit) => cubit.state.unreadCount,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: PlatformHoverBuilder(
        builder: (context, isHovered, child) => AnimatedScale(
          scale: isHovered ? 1.08 : 1.0,
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          child: child,
        ),
        child: ShrinkableButton(
          onTap: () {
            unawaited(HapticFeedback.lightImpact());
            unawaited(context.router.push(const NotificationsRoute()));
          },
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary
                  : colors.surfaceSecondary.withAlpha(140),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 80 : 60),
              ),
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 19,
                  color: colors.textSecondary,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
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
    );
  }
}

class _CommunitySearchFilterCapsule extends StatelessWidget {
  const _CommunitySearchFilterCapsule({
    required this.hasActiveFilters,
    required this.activeFilterCount,
    required this.isDark,
    required this.onOpenSearch,
    required this.onOpenFilter,
  });

  final bool hasActiveFilters;
  final int activeFilterCount;
  final bool isDark;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
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
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.08 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: child,
              ),
              child: ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onOpenSearch();
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
              builder: (context, isHovered, child) => AnimatedScale(
                scale: isHovered ? 1.08 : 1.0,
                duration: AppMotion.snappy,
                curve: AppMotion.easeOutCubic,
                child: child,
              ),
              child: ShrinkableButton(
                onTap: () {
                  unawaited(HapticFeedback.lightImpact());
                  onOpenFilter();
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
    );
  }
}
