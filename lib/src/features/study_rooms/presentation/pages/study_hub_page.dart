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
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/auto_community_cubit.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/pages/create_forum_discussion_page.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_filter_bottom_sheet.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_forum_feed_list.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_headers.dart';
import 'package:kortex/src/features/community/presentation/widgets/community_hub_shimmer.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:kortex/src/features/dashboard/presentation/bloc/dashboard_event.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/pages/deck_marketplace_detail_page.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/marketplace_deck_card.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/publish_deck_modal_sheet.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_bloc.dart';
import 'package:kortex/src/features/decks/presentation/bloc/decks_event.dart';
import 'package:kortex/src/features/notifications/presentation/bloc/notifications_cubit.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<CommunityHubBloc>.value(
          value:
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
      child: const _StudyHubView(),
    );
  }
}

Widget _buildHeaderActionButton(
  BuildContext context, {
  required int tabIndex,
  required bool isWide,
  required String? targetTrack,
}) {
  final colors = context.colors;
  final typography = context.typography;
  final l10n = context.l10n;
  final isDark = context.isDarkMode;

  IconData icon;
  String label;
  VoidCallback onTap;

  final effectiveActionIndex = isWide ? tabIndex + 1 : tabIndex;

  switch (effectiveActionIndex) {
    case 0:
      icon = Icons.edit_note_rounded;
      label = 'Post Thread';
      onTap = () async {
        unawaited(HapticFeedback.lightImpact());
        final hubBloc = context.read<CommunityHubBloc>();
        final initialTrack = targetTrack ?? hubBloc.state.selectedTrack;
        final created = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: hubBloc,
              child: CreateForumDiscussionPage(
                initialTrack: initialTrack.isNotEmpty ? initialTrack : 'WAEC',
              ),
            ),
          ),
        );
        if (created == true) {
          hubBloc.add(
            ChangeForumSortFilterEvent(hubBloc.state.selectedForumFilter),
          );
        }
      };
    case 1:
      icon = Icons.add_rounded;
      label = l10n.newRoomAction;
      onTap = () {
        unawaited(HapticFeedback.lightImpact());
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
              context.showSnackBar(
                message: '✨ Launching Live Focus Room "$title"...',
                type: SnackBarType.success,
              );
            },
          ),
        );
      };
    case 2:
      icon = Icons.groups_rounded;
      label = 'Start Pod';
      onTap = () {
        unawaited(HapticFeedback.lightImpact());
        unawaited(
          CreateStudyCircleSheet.show(
            context,
            initialTrack: targetTrack ?? 'General',
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
              context.showSnackBar(
                message: '🎉 Study Pod "$name" created successfully!',
                type: SnackBarType.success,
              );
            },
          ),
        );
      };
    default:
      icon = Icons.publish_rounded;
      label = 'Publish Deck';
      onTap = () {
        unawaited(HapticFeedback.lightImpact());
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
      };
  }

  return PlatformHoverBuilder(
    builder: (context, isHovered, child) => AnimatedScale(
      scale: isHovered ? 1.03 : 1,
      duration: AppMotion.snappy,
      curve: AppMotion.easeOutCubic,
      child: ShrinkableButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.snappy,
          curve: AppMotion.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isHovered
                ? colors.primary.withAlpha(isDark ? 65 : 45)
                : colors.primary.withAlpha(isDark ? 40 : 25),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: isHovered
                  ? colors.primary
                  : colors.primary.withAlpha(isDark ? 80 : 50),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colors.primary, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
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
  );
}

/// Breakpoint at which Hub tabs switch from a single-column list to a 2-column grid.
/// Used for tablet, landscape phone, and desktop layouts.
const double _kHubGridBreakpoint = 600;

class _StudyHubView extends HookWidget {
  const _StudyHubView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isWide = AppTabNavigation.isWideLayout(screenWidth);

    final tabController = useTabController(
      initialLength: isWide ? 3 : 4,
      keys: [isWide],
    );
    useListenable(tabController);

    useEffect(() {
      void handler(int index) {
        if (tabController.length > index) {
          tabController.animateTo(index);
        }
      }

      AppTabNavigation.onSelectStudyHubSubTab = handler;
      AppTourKeys.onSelectStudyHubSubTab = handler;

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
                    if (!isWide && tabController.index == 0) ...[
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
                      child: _buildHeaderActionButton(
                        context,
                        tabIndex: tabController.index,
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
                      key: AppTourKeys.pomodoroCardKey = AppTourKeys.safeKey(
                        AppTourKeys.pomodoroCardKey,
                        'tour_pomodoro_card',
                      ),
                      tabs: isWide
                          ? [
                              l10n.liveRoomsTab,
                              'Study Pods',
                              l10n.marketplaceTab,
                            ]
                          : [
                              l10n.forumTab,
                              l10n.liveRoomsTab,
                              'Study Pods',
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
                  state.sharedDecks.isEmpty &&
                  state.forumPosts.isEmpty) {
                return CommunityHubShimmer(
                  tabIndex: tabController.index == 1 ? 0 : 2,
                );
              }

              final hubTabBarView = TabBarView(
                controller: tabController,
                children: isWide
                    ? [
                        // 0. Live Focus Rooms
                        _LiveRoomsTab(
                          key: AppTourKeys.liveRoomsCardKey = AppTourKeys.safeKey(
                            AppTourKeys.liveRoomsCardKey,
                            'tour_live_rooms_card',
                          ),
                          state: state,
                          targetTrack: targetTrack,
                          hasSelectedDeck: hasSelectedDeck,
                        ),

                        // 1. Study Circles
                        _StudyCirclesTab(
                          state: state,
                          targetTrack: targetTrack,
                          hasSelectedDeck: hasSelectedDeck,
                        ),

                        // 2. Deck Marketplace
                        _DeckMarketplaceTab(
                          key: AppTourKeys.marketplaceCardKey =
                              AppTourKeys.safeKey(
                            AppTourKeys.marketplaceCardKey,
                            'tour_marketplace_card',
                          ),
                          state: state,
                          selectedDeckId: selectedDesktopDeck.value?.id,
                          hasSelectedDeck: hasSelectedDeck,
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
                      ]
                    : [
                        // 0. Academic Forum Feed
                        _ForumTab(
                          state: state,
                          targetTrack: targetTrack,
                        ),

                        // 1. Live Focus Rooms
                        _LiveRoomsTab(
                          key: AppTourKeys.liveRoomsCardKey = AppTourKeys.safeKey(
                            AppTourKeys.liveRoomsCardKey,
                            'tour_live_rooms_card',
                          ),
                          state: state,
                          targetTrack: targetTrack,
                          hasSelectedDeck: hasSelectedDeck,
                        ),

                        // 2. Study Circles
                        _StudyCirclesTab(
                          state: state,
                          targetTrack: targetTrack,
                          hasSelectedDeck: hasSelectedDeck,
                        ),

                        // 3. Deck Marketplace
                        _DeckMarketplaceTab(
                          key: AppTourKeys.marketplaceCardKey =
                              AppTourKeys.safeKey(
                            AppTourKeys.marketplaceCardKey,
                            'tour_marketplace_card',
                          ),
                          state: state,
                          selectedDeckId: selectedDesktopDeck.value?.id,
                          hasSelectedDeck: hasSelectedDeck,
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

class _LiveRoomsTab extends StatefulWidget {
  const _LiveRoomsTab({
    required this.state,
    required this.targetTrack,
    this.hasSelectedDeck = false,
    super.key,
  });

  final CommunityState state;
  final String? targetTrack;
  final bool hasSelectedDeck;

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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isGrid = screenWidth >= _kHubGridBreakpoint;
    final isDesktop = screenWidth >= 1024;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 80;

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
          constraints: BoxConstraints(
            maxWidth: widget.hasSelectedDeck ? 520 : (isDesktop ? 1400 : 860),
          ),
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
                                  child: Text(l10n.studyHubViewAllTracks),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (isGrid)
                // 2-column grid layout for tablet / landscape / desktop
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 440,
                      mainAxisExtent: 168,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final room = filteredRooms[index];
                        return LiveFocusRoomCard(
                          room: room,
                          onJoinTap: () {
                            unawaited(
                              context.router.push(
                                LiveStudyRoomRoute(room: room),
                              ),
                            );
                          },
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
                )
              else
                // Single-column list for compact / portrait phone
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
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
    this.hasSelectedDeck = false,
  });

  final CommunityState state;
  final String? targetTrack;
  final bool hasSelectedDeck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final isDark = context.isDarkMode;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1024;
    final isGrid = !hasSelectedDeck && (screenWidth >= _kHubGridBreakpoint);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 80;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CommunityHubBloc>().add(const LoadCommunityHubEvent());
      },
      color: colors.primary,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: hasSelectedDeck ? 520 : (isDesktop ? 1400 : 860),
          ),
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
                              'What are Study Pods?',
                              style: typography.subhead.bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Study Pods are small peer study groups of up to 6 scholars taking the same track. Join a pod to commit to a collective weekly focus target, monitor contributions, and send instant nudges to keep each other accountable.',
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
                        'Peer Study Pods',
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${state.studyCircles.length} ${state.studyCircles.length == 1 ? 'Pod' : 'Pods'}',
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
              else if (isGrid)
                // 2-column grid layout for tablet / desktop viewports
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isDesktop ? 650 : 540,
                      mainAxisExtent: 295,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final circle = state.studyCircles[index];
                        return StudyCircleCard(
                          circle: circle,
                          margin: EdgeInsets.zero,
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
                )
              else
                // Single-column list layout for narrow mobile viewports
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
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
  const _DeckMarketplaceTab({
    required this.state,
    this.selectedDeckId,
    this.hasSelectedDeck = false,
    this.onDeckSelected,
    super.key,
  });

  final CommunityState state;
  final String? selectedDeckId;
  final bool hasSelectedDeck;
  final ValueChanged<SharedDeckEntity>? onDeckSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 1024;
    final isGrid = !hasSelectedDeck && (screenWidth >= _kHubGridBreakpoint);
    final gridCrossAxisCount = isDesktop && !hasSelectedDeck ? 3 : (isGrid ? 2 : 1);
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom + 80;

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
          constraints: BoxConstraints(
            maxWidth: hasSelectedDeck ? 520 : (isDesktop ? 1400 : 860),
          ),
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
                                  fillColor: Colors.transparent,
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
              else if (gridCrossAxisCount > 1)
                // Multi-column grid layout for desktop / tablet when 3rd panel is hidden
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCrossAxisCount,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: gridCrossAxisCount == 3 ? 1.85 : 1.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = filteredDecks[index];
                        final isSelected = selectedDeckId == deck.id;
                        return MarketplaceDeckCard(
                          deck: deck,
                          isSelected: isSelected,
                          onCloneTap: () {
                            context.read<CommunityHubBloc>().add(
                              CloneDeckEvent(deck.id),
                            );
                          },
                          onTap: () {
                            if (onDeckSelected != null) {
                              onDeckSelected!(deck);
                            } else {
                              unawaited(
                                context.router.push(
                                  DeckMarketplaceDetailRoute(deck: deck),
                                ),
                              );
                            }
                          },
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
                )
              else
                // Single-column list when 3rd panel is open or phone compact view
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final deck = filteredDecks[index];
                        final isSelected = selectedDeckId == deck.id;
                        return MarketplaceDeckCard(
                          deck: deck,
                          isSelected: isSelected,
                          onCloneTap: () {
                            context.read<CommunityHubBloc>().add(
                              CloneDeckEvent(deck.id),
                            );
                          },
                          onTap: () {
                            if (onDeckSelected != null) {
                              onDeckSelected!(deck);
                            } else {
                              unawaited(
                                context.router.push(
                                  DeckMarketplaceDetailRoute(deck: deck),
                                ),
                              );
                            }
                          },
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

class _ForumTab extends StatelessWidget {
  const _ForumTab({
    required this.state,
    required this.targetTrack,
  });

  final CommunityState state;
  final String? targetTrack;

  @override
  Widget build(BuildContext context) {
    final effectiveTrack = (targetTrack != null &&
            targetTrack!.trim().isNotEmpty &&
            targetTrack != 'General')
        ? targetTrack!.trim()
        : 'WAEC';

    final availableTracks = getAvailableTracks(targetTrack);

    return CommunityForumFeedList(
      state: state,
      searchQuery: state.forumSearchQuery,
      availableTracks: availableTracks,
      effectiveTrack: effectiveTrack,
    );
  }
}
