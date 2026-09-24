import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/leaderboard/domain/entities/leaderboard_entry_entity.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_floating_hud.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_shimmer_view.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/streak_leaderboard_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

// Available league tiers for the filter sheet
const _kTiers = ['All', 'Diamond', 'Platinum', 'Gold', 'Silver', 'Bronze'];

@RoutePage()
class LeaderboardPage extends HookWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommunityHubBloc>(
      create: (_) =>
          locator<CommunityHubBloc>()..add(const LoadCommunityHubEvent()),
      child: const _LeaderboardView(),
    );
  }
}

class _LeaderboardView extends HookWidget {
  const _LeaderboardView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final scrollController = useScrollController();
    final searchController = useTextEditingController();
    final searchQuery = useState('');
    final selectedTier = useState('All');

    // Keep searchQuery reactive to text changes
    useEffect(() {
      void onChanged() => searchQuery.value = searchController.text;
      searchController.addListener(onChanged);
      return () => searchController.removeListener(onChanged);
    }, [searchController]);

    final authState = context.watch<AuthBloc?>()?.state;
    final liveFreezes = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>().getStreakFreezes()
        : 0;
    final effectiveStreakFreezes =
        (authState?.userProfile?.streakFreezeCount ?? 0) > liveFreezes
        ? (authState?.userProfile?.streakFreezeCount ?? 0)
        : liveFreezes;

    final hasActiveFilter = selectedTier.value != 'All';

    void openFilterSheet() {
      AppFeedback.selection();
      unawaited(
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: colors.surfacePrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (sheetCtx) => _FilterSheet(
            selectedTier: selectedTier.value,
            onTierSelected: (tier) {
              selectedTier.value = tier;
              Navigator.of(sheetCtx).pop();
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      body: BlocBuilder<CommunityHubBloc, CommunityState>(
        builder: (context, state) {
          // ── Client-side search + filter ─────────────────────────────────
          final filteredEntries = _filterEntries(
            entries: state.leaderboardEntries,
            query: searchQuery.value,
            tier: selectedTier.value,
          );

          final currentUserEntry =
              filteredEntries.where((e) => e.isCurrentUser).firstOrNull;
          final nextUserEntry = currentUserEntry != null &&
                  currentUserEntry.rank > 1
              ? filteredEntries
                  .where((e) => e.rank == currentUserEntry.rank - 1)
                  .firstOrNull
              : null;

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  context.read<CommunityHubBloc>().add(
                    const LoadCommunityHubEvent(),
                  );
                },
                color: colors.primary,
                child: CustomScrollView(
                  controller: scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // ── Sticky App Bar + wired Search + Filter ──────────
                    SliverAppBar(
                      backgroundColor: isDark
                          ? colors.backgroundPrimary.withAlpha(240)
                          : colors.surfacePrimary.withAlpha(240),
                      elevation: 0,
                      scrolledUnderElevation: 4,
                      pinned: true,
                      centerTitle: false,
                      title: Text(
                        l10n.leaderboardTab,
                        style: typography.title2.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(60),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: searchController,
                                  textInputAction: TextInputAction.search,
                                  decoration: InputDecoration(
                                    hintText: 'Search scholars...',
                                    hintStyle: typography.caption.regular
                                        .copyWith(color: colors.textSecondary),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: colors.textSecondary,
                                      size: 20,
                                    ),
                                    suffixIcon: searchQuery.value.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                              color: colors.textSecondary,
                                            ),
                                            onPressed: searchController.clear,
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: isDark
                                        ? colors.surfaceSecondary
                                        : colors.gray.withAlpha(20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: openFilterSheet,
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: hasActiveFilter
                                        ? colors.primary
                                        : colors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.filter_list,
                                    color: hasActiveFilter
                                        ? colors.white
                                        : colors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Active-filter chip ───────────────────────────────
                    if (hasActiveFilter)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              Chip(
                                label: Text(
                                  selectedTier.value,
                                  style: typography.caption.medium.copyWith(
                                    color: colors.primary,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: colors.primary.withAlpha(20),
                                side: BorderSide(
                                  color: colors.primary.withAlpha(60),
                                ),
                                deleteIcon: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: colors.primary,
                                ),
                                onDeleted: () => selectedTier.value = 'All',
                              ),
                            ],
                          ),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: (state.status == CommunityStatus.loading &&
                                    state.leaderboardEntries.isEmpty)
                                ? const LeaderboardShimmerView()
                                : filteredEntries.isEmpty
                                    ? _EmptySearchState(
                                        query: searchQuery.value,
                                        tier: selectedTier.value,
                                      )
                                    : StreakLeaderboardWidget(
                                        entries: filteredEntries,
                                        streakFreezeCount:
                                            effectiveStreakFreezes,
                                      ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (currentUserEntry != null &&
                  state.status != CommunityStatus.loading)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: LeaderboardFloatingHud(
                        currentUserEntry: currentUserEntry,
                        nextUserEntry: nextUserEntry,
                        onJumpToMe: () {
                          final targetOffset =
                              300.0 + (currentUserEntry.rank * 80.0);
                          unawaited(
                            scrollController.animateTo(
                              targetOffset,
                              duration: AppMotion.expressive,
                              curve: AppMotion.easeOutCubic,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<LeaderboardEntryEntity> _filterEntries({
    required List<LeaderboardEntryEntity> entries,
    required String query,
    required String tier,
  }) {
    var result = entries;
    if (query.trim().isNotEmpty) {
      final lower = query.trim().toLowerCase();
      result = result
          .where(
            (e) =>
                e.userName.toLowerCase().contains(lower) ||
                e.track.toLowerCase().contains(lower),
          )
          .toList();
    }
    if (tier != 'All') {
      result = result
          .where((e) => e.leagueTier.toLowerCase() == tier.toLowerCase())
          .toList();
    }
    return result;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Filter bottom sheet
// ────────────────────────────────────────────────────────────────────────────
class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.selectedTier,
    required this.onTierSelected,
  });

  final String selectedTier;
  final ValueChanged<String> onTierSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: c.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'FILTER BY LEAGUE',
              style: t.caption.bold.copyWith(
                color: c.textSecondary.withAlpha(170),
                fontSize: 11,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _kTiers.map((tier) {
                final isSelected = tier == selectedTier;
                return GestureDetector(
                  onTap: () {
                    AppFeedback.selection();
                    onTierSelected(tier);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.snappy,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected ? c.primary : c.primary.withAlpha(18),
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: isSelected
                            ? c.primary
                            : c.primary.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tier != 'All') ...[
                          _TierDot(tier: tier),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          tier,
                          style: t.caption.bold.copyWith(
                            color: isSelected ? c.white : c.primary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierDot extends StatelessWidget {
  const _TierDot({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    final color = switch (tier.toLowerCase()) {
      'diamond' => const Color(0xFF7ECEFD),
      'platinum' => const Color(0xFFB0C4D8),
      'gold' => const Color(0xFFFFD700),
      'silver' => const Color(0xFFC0C0C0),
      _ => const Color(0xFFCD7F32),
    };
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Empty state
// ────────────────────────────────────────────────────────────────────────────
class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query, required this.tier});

  final String query;
  final String tier;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.typography;
    final msg = query.isNotEmpty
        ? 'No scholars matching "$query"'
        : 'No scholars in the $tier league';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: c.textSecondary),
          const SizedBox(height: 12),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: t.body.medium.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}
