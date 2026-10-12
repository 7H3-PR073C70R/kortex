import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_filter_bottom_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_headers.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_shimmer.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/pages/deck_marketplace_detail_page.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_deck_marketplace_tab.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_forum_tab.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_header_action_button.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_live_rooms_tab.dart';
import 'package:kortex/src/features/study_rooms/presentation/widgets/study_hub/study_hub_study_circles_tab.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';

@RoutePage()
class StudyHubPage extends HookWidget {
  const StudyHubPage({
    this.decksBloc,
    this.communityHubBloc,
    this.autoCommunityCubit,
    this.notificationsCubit,
    this.dashboardBloc,
    super.key,
  });

  final DecksBloc? decksBloc;
  final CommunityHubBloc? communityHubBloc;
  final AutoCommunityCubit? autoCommunityCubit;
  final NotificationsCubit? notificationsCubit;
  final DashboardBloc? dashboardBloc;

  @override
  Widget build(BuildContext context) {
    final resolvedDecksBloc = decksBloc ??
        (locator.isRegistered<DecksBloc>() ? locator<DecksBloc>() : null);
    final resolvedCommunityHubBloc = communityHubBloc ??
        (locator.isRegistered<CommunityHubBloc>()
            ? (locator<CommunityHubBloc>()..add(const LoadCommunityHubEvent()))
            : null);
    final resolvedAutoCommunityCubit = autoCommunityCubit ??
        (locator.isRegistered<AutoCommunityCubit>()
            ? locator<AutoCommunityCubit>()
            : null);
    final resolvedNotificationsCubit = notificationsCubit ??
        (locator.isRegistered<NotificationsCubit>()
            ? locator<NotificationsCubit>()
            : NotificationsCubit());
    final resolvedDashboardBloc = dashboardBloc ??
        (locator.isRegistered<DashboardBloc>()
            ? locator<DashboardBloc>()
            : null);

    final providers = <BlocProvider>[
      if (resolvedDecksBloc != null)
        BlocProvider<DecksBloc>.value(value: resolvedDecksBloc),
      if (resolvedCommunityHubBloc != null)
        BlocProvider<CommunityHubBloc>.value(value: resolvedCommunityHubBloc),
      if (resolvedAutoCommunityCubit != null)
        BlocProvider<AutoCommunityCubit>.value(
          value: resolvedAutoCommunityCubit,
        ),
      BlocProvider<NotificationsCubit>.value(value: resolvedNotificationsCubit),
    ];

    final view = _StudyHubView(
      decksBloc: resolvedDecksBloc,
      dashboardBloc: resolvedDashboardBloc,
    );

    if (providers.isEmpty) {
      return view;
    }

    return MultiBlocProvider(
      providers: providers,
      child: view,
    );
  }
}

class _StudyHubView extends HookWidget {
  const _StudyHubView({
    this.decksBloc,
    this.dashboardBloc,
  });

  final DecksBloc? decksBloc;
  final DashboardBloc? dashboardBloc;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = AppTabNavigation.isWideLayout(screenWidth);

    final hubSubTabs = AppTabNavigation.hubSubTabs(isWide: isWide);
    final tabController = useTabController(
      initialLength: hubSubTabs.length,
      keys: [isWide],
    );
    useListenable(tabController);
    final activeSubTab =
        hubSubTabs[tabController.index.clamp(0, hubSubTabs.length - 1)];

    useEffect(() {
      void selectSubTab(StudyHubSubTab subTab) {
        final index = AppTabNavigation.hubTabControllerIndex(
          subTab,
          isWide: isWide,
        );
        if (index != null && index < tabController.length) {
          tabController.animateTo(index);
        }
      }

      void handler(int logicalIndex) {
        if (logicalIndex < 0 ||
            logicalIndex >= StudyHubSubTab.values.length) {
          return;
        }
        selectSubTab(StudyHubSubTab.values[logicalIndex]);
      }

      AppTabNavigation.onSelectStudyHubSubTab = handler;
      AppTourKeys.onSelectStudyHubSubTab = handler;

      final pending = AppTabNavigation.pendingHubSubTab;
      if (pending != null) {
        AppTabNavigation.pendingHubSubTab = null;
        selectSubTab(pending);
      }

      return () {
        AppTabNavigation.onSelectStudyHubSubTab = null;
        AppTourKeys.onSelectStudyHubSubTab = null;
      };
    }, [tabController]);

    final isSearchExpanded = useState<bool>(false);
    final searchQuery = useState<String>('');
    final searchController = useTextEditingController();
    final debounceTimer = useRef<Timer?>(null);
    final selectedDesktopDeck = useState<SharedDeckEntity?>(null);

    useEffect(() {
      return () => debounceTimer.value?.cancel();
    }, const []);

    useEffect(() {
      void onTabChange() {
        if (isSearchExpanded.value) {
          isSearchExpanded.value = false;
        }
      }

      tabController.addListener(onTabChange);
      return () => tabController.removeListener(onTabChange);
    }, [tabController]);

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
            hubState.selectedForumFilter.isNotEmpty) ||
        hubState.forumSearchQuery.isNotEmpty;
    final activeFilterCount = (hubState.selectedTrack != 'All' ? 1 : 0) +
        (hubState.selectedForumFilter != 'trending' &&
                hubState.selectedForumFilter.isNotEmpty
            ? 1
            : 0) +
        (hubState.forumSearchQuery.isNotEmpty ? 1 : 0);

    final hasSelectedDeck = isWide && selectedDesktopDeck.value != null;

    return Focus(
      autofocus: hasSelectedDeck,
      onKeyEvent: (node, event) {
        if (hasSelectedDeck &&
            event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          selectedDesktopDeck.value = null;
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: BlocListener<CommunityHubBloc, CommunityState>(
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
                  : Text(
                      'Hub',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
            ),
            actions: isSearchExpanded.value
                ? null
                : [
                    if (activeSubTab == StudyHubSubTab.forum) ...[
                      CommunitySearchFilterCapsule(
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
                    ],
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: StudyHubHeaderActionButton(
                        subTab: activeSubTab,
                        isWide: isWide,
                        targetTrack: targetTrack,
                      ),
                    ),
                  ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: hasSelectedDeck ? 520 : 860,
                    ),
                    child: AppLiquidGlassTabBar(
                      key: AppTourKeys.pomodoroCardKey,
                      tabs: [
                        for (final subTab in hubSubTabs)
                          switch (subTab) {
                            StudyHubSubTab.forum => l10n.forumTab,
                            StudyHubSubTab.liveRooms => l10n.liveRoomsTab,
                            StudyHubSubTab.studyCircles => 'Study Pods',
                            StudyHubSubTab.marketplace => l10n.marketplaceTab,
                          },
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
                final targetDecksBloc = decksBloc ??
                    (locator.isRegistered<DecksBloc>()
                        ? locator<DecksBloc>()
                        : null);
                targetDecksBloc?.add(const DecksRefreshed());

                final targetDashboardBloc = dashboardBloc ??
                    (locator.isRegistered<DashboardBloc>()
                        ? locator<DashboardBloc>()
                        : null);
                targetDashboardBloc?.add(const DashboardRefreshed());

                context.showSnackBar(
                  message: l10n.deckClonedSuccessNotice,
                );
              }
            },
            builder: (context, state) {
              if (state.status == CommunityStatus.loading &&
                  state.studyRooms.isEmpty &&
                  state.sharedDecks.isEmpty &&
                  state.forumPosts.isEmpty) {
                return CommunityHubShimmer(
                  tabIndex: switch (activeSubTab) {
                    StudyHubSubTab.forum => 1,
                    StudyHubSubTab.marketplace => 2,
                    _ => 0,
                  },
                );
              }

              final hubTabBarView = TabBarView(
                controller: tabController,
                children: [
                  for (final subTab in hubSubTabs)
                    switch (subTab) {
                      StudyHubSubTab.forum => StudyHubForumTab(
                          state: state,
                          targetTrack: targetTrack,
                        ),
                      StudyHubSubTab.liveRooms => StudyHubLiveRoomsTab(
                          key: AppTourKeys.liveRoomsCardKey,
                          state: state,
                          targetTrack: targetTrack,
                          hasSelectedDeck: hasSelectedDeck,
                        ),
                      StudyHubSubTab.studyCircles => StudyHubStudyCirclesTab(
                          state: state,
                          targetTrack: targetTrack,
                          hasSelectedDeck: hasSelectedDeck,
                        ),
                      StudyHubSubTab.marketplace =>
                        StudyHubDeckMarketplaceTab(
                          key: AppTourKeys.marketplaceCardKey,
                          state: state,
                          selectedDeckId: selectedDesktopDeck.value?.id,
                          hasSelectedDeck: hasSelectedDeck,
                          decksBloc: decksBloc,
                          onDeckSelected: (deck) {
                            if (isWide) {
                              selectedDesktopDeck.value = deck;
                            } else {
                              unawaited(
                                context.router.push(
                                  DeckMarketplaceDetailRoute(deck: deck),
                                ),
                              );
                            }
                          },
                        ),
                    },
                ],
              );

              if (!hasSelectedDeck) {
                return hubTabBarView;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // PANEL 2: Main Hub Tab View (Fixed 520px when Deck Detail Inspector is active on desktop)
                  AnimatedContainer(
                    duration: AppMotion.expressive,
                    curve: AppMotion.easeOutCubic,
                    width: 520,
                    child: hubTabBarView,
                  ),

                  // Pane Divider 2
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(50)
                        : colors.surfaceBorder,
                  ),

                  // PANEL 3: Deck Marketplace Detail & Preview View
                  Expanded(
                    child: DeckMarketplaceDetailPage(
                      key: ValueKey(selectedDesktopDeck.value!.id),
                      deck: selectedDesktopDeck.value!,
                      onClosePanel: () {
                        selectedDesktopDeck.value = null;
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
