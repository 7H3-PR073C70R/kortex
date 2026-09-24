import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_floating_hud.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/leaderboard_shimmer_view.dart';
import 'package:kortex/src/features/leaderboard/presentation/widgets/streak_leaderboard_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

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

    final authState = context.watch<AuthBloc?>()?.state;
    final liveFreezes = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>().getStreakFreezes()
        : 0;
    final effectiveStreakFreezes =
        (authState?.userProfile?.streakFreezeCount ?? 0) > liveFreezes
        ? (authState?.userProfile?.streakFreezeCount ?? 0)
        : liveFreezes;

    return Scaffold(
      backgroundColor: isDark
          ? colors.backgroundPrimary
          : colors.surfacePrimary,
      body: BlocBuilder<CommunityHubBloc, CommunityState>(
        builder: (context, state) {
          final currentUserEntry = state.leaderboardEntries.where((e) => e.isCurrentUser).firstOrNull;
          final nextUserEntry = currentUserEntry != null && currentUserEntry.rank > 1 
              ? state.leaderboardEntries.where((e) => e.rank == currentUserEntry.rank - 1).firstOrNull 
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
                    SliverAppBar(
                      backgroundColor: isDark ? colors.backgroundPrimary.withAlpha(240) : colors.surfacePrimary.withAlpha(240),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search scholars...',
                                    prefixIcon: const Icon(Icons.search),
                                    filled: true,
                                    fillColor: isDark ? colors.surfaceSecondary : colors.gray.withAlpha(20),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.filter_list, color: colors.primary, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      sliver: SliverToBoxAdapter(
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 680),
                            child: (state.status == CommunityStatus.loading && state.leaderboardEntries.isEmpty)
                                ? const LeaderboardShimmerView()
                                : StreakLeaderboardWidget(
                                    entries: state.leaderboardEntries,
                                    streakFreezeCount: effectiveStreakFreezes,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (currentUserEntry != null && state.status != CommunityStatus.loading)
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
                          // Approximate scroll based on rank
                          final targetOffset = 300.0 + (currentUserEntry.rank * 80.0);
                          unawaited(scrollController.animateTo(
                            targetOffset,
                            duration: AppMotion.expressive,
                            curve: AppMotion.easeOutCubic,
                          ));
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
}
