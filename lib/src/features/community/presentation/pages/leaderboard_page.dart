import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/user_activity_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_event.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_hub_bloc.dart';
import 'package:kortex/src/features/community/presentation/bloc/community_state.dart';
import 'package:kortex/src/features/community/presentation/widgets/streak_leaderboard_widget.dart';
import 'package:kortex/src/l10n/l10n.dart';

@RoutePage()
class LeaderboardPage extends HookWidget {
  const LeaderboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CommunityHubBloc>(
      create: (_) => locator<CommunityHubBloc>()..add(const LoadCommunityHubEvent()),
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

    final authState = context.watch<AuthBloc?>()?.state;
    final liveFreezes = locator.isRegistered<UserActivityService>()
        ? locator<UserActivityService>().getStreakFreezes()
        : 0;
    final effectiveStreakFreezes = (authState?.userProfile?.streakFreezeCount ?? 0) > liveFreezes
        ? (authState?.userProfile?.streakFreezeCount ?? 0)
        : liveFreezes;

    return Scaffold(
      backgroundColor: isDark ? colors.backgroundPrimary : colors.surfacePrimary,
      appBar: AppBar(
        backgroundColor: colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(
          l10n.leaderboardTab,
          style: typography.title2.bold.copyWith(
            color: colors.textPrimary,
          ),
        ),
      ),
      body: BlocBuilder<CommunityHubBloc, CommunityState>(
        builder: (context, state) {
          if (state.status == CommunityStatus.loading && state.leaderboardEntries.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: colors.primary,
                strokeWidth: 2.5,
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<CommunityHubBloc>().add(const LoadCommunityHubEvent());
            },
            color: colors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: StreakLeaderboardWidget(
                entries: state.leaderboardEntries,
                streakFreezeCount: effectiveStreakFreezes,
              ),
            ),
          );
        },
      ),
    );
  }
}
