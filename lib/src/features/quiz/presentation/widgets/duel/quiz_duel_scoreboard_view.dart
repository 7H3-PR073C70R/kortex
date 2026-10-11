import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/duel/quiz_duel_rematch_section.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_review_tab.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';
import 'package:kortex/src/shared/widgets/app_liquid_glass_tab_bar.dart';

/// Post-match view displaying victor emblem, synchronized scoreboard, study review tab, and rematch controls.
class QuizDuelScoreboardView extends StatelessWidget {
  const QuizDuelScoreboardView({
    required this.state,
    required this.activeTab,
    required this.onTabSelected,
    required this.onAcceptRematch,
    required this.onDeclineRematch,
    required this.onCancelRematchRequest,
    required this.onRequestRematch,
    required this.onRematchWithAi,
    required this.onFindNewRival,
    required this.onShareDuel,
    required this.onReturnToDashboard,
    super.key,
  });

  final QuizDuelState state;
  final int activeTab;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAcceptRematch;
  final VoidCallback onDeclineRematch;
  final VoidCallback onCancelRematchRequest;
  final VoidCallback onRequestRematch;
  final VoidCallback onRematchWithAi;
  final VoidCallback onFindNewRival;
  final VoidCallback onShareDuel;
  final VoidCallback onReturnToDashboard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final match = state.match;
    final isWinner = state.isWinner;
    final isDraw = state.isDraw;
    final p1 = match?.player1;
    final p2 = match?.player2;
    final p1Score = p1?.score ?? 0;
    final p2Score = p2?.score ?? 0;

    final p1Won = match?.winnerUserId == p1?.userId ||
        (match?.winnerUserId == null && p1Score > p2Score && !isDraw);
    final p2Won = match?.winnerUserId == p2?.userId ||
        (match?.winnerUserId == null && p2Score > p1Score && !isDraw);

    final winnerName = p1Won
        ? (p1?.displayName ?? 'Player 1')
        : p2Won
            ? (p2?.displayName ?? 'Player 2')
            : 'Neither';
    final winnerScore = p1Won ? p1Score : p2Score;

    final isForfeit = match?.isForfeit ?? false;
    final forfeitByRival =
        isForfeit && match?.forfeitUserId != state.currentUserId;
    final opponentName = p1?.userId == state.currentUserId
        ? (p2?.displayName ?? 'Opponent')
        : (p1?.displayName ?? 'Opponent');

    final opponent = state.opponentParticipant ??
        const QuizDuelParticipant(
          userId: '',
          displayName: 'Rival',
          avatarUrl: '🧠',
        );

    return Scaffold(
      backgroundColor: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Winner Emblem Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDraw
                            ? colors.warning.withAlpha(30)
                            : isWinner
                                ? colors.success.withAlpha(30)
                                : colors.primary.withAlpha(30),
                      ),
                      child: Text(
                        isDraw ? '⚔️' : '🏆',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      forfeitByRival
                          ? 'Rival Forfeited! Victory Awarded'
                          : isForfeit
                              ? 'Match Forfeited'
                              : isDraw
                                  ? "It's a Draw!"
                                  : '$winnerName Won the Duel!',
                      textAlign: TextAlign.center,
                      style: typography.largeTitle.bold.copyWith(
                        color: isDraw ? colors.warning : colors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      forfeitByRival
                          ? '$opponentName left the arena. You have been awarded +500 victory points!'
                          : isForfeit
                              ? 'A player left the match early.'
                              : isDraw
                                  ? 'Both scholars tied with $p1Score pts in a fierce battle.'
                                  : 'Winner declared with $winnerScore pts in real-time!',
                      textAlign: TextAlign.center,
                      style: typography.body.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Post-Match Liquid Glass Tab Bar
                    AppLiquidGlassTabBar(
                      tabs: const ['Scoreboard', 'Study Review'],
                      icons: const [
                        Icons.emoji_events_rounded,
                        Icons.menu_book_rounded,
                      ],
                      selectedIndex: activeTab,
                      onTabSelected: onTabSelected,
                    ),
                    const SizedBox(height: 20),

                    if (activeTab == 1 && match != null)
                      SizedBox(
                        height: 440,
                        child: QuizDuelReviewTab(
                          match: match,
                          currentUserId: state.currentUserId,
                          onRematch: onRequestRematch,
                        ),
                      )
                    else
                      // Synchronized Real-Time Scoreboard Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(
                            AppRadius.panel,
                          ),
                          border: Border.all(
                            color: colors.surfaceBorder.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(isDark ? 50 : 20),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'DUEL SCOREBOARD',
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (match?.roomCode != null &&
                                match!.roomCode!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.micro,
                                  ),
                                  border: Border.all(
                                    color: colors.primary.withAlpha(60),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'ROOM: ${match.roomCode}',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.primary,
                                    fontSize: 11,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                // Player 1
                                Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AppAvatar(
                                          name: p1?.displayName ?? 'Player 1',
                                          customDimension: 56,
                                        ),
                                        if (p1Won && !isDraw)
                                          Positioned(
                                            top: -8,
                                            right: -8,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: colors.warning,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.emoji_events_rounded,
                                                size: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p1?.displayName ?? 'Player 1',
                                      style: typography.body.bold,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${p1?.score ?? 0} pts',
                                      style: typography.title2.bold.copyWith(
                                        color: p1Won
                                            ? colors.success
                                            : colors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (p1Won && !isDraw)
                                      const AppBadge(
                                        label: '🏆 Winner',
                                        variant: AppBadgeVariant.success,
                                      )
                                    else if (isDraw)
                                      const AppBadge(
                                        label: '⚔️ Tied',
                                        variant: AppBadgeVariant.warning,
                                      )
                                    else
                                      const AppBadge(
                                        label: 'Runner-up',
                                        variant: AppBadgeVariant.secondary,
                                      ),
                                  ],
                                ),
                                Text(
                                  'VS',
                                  style: typography.title2.bold.copyWith(
                                    color: colors.textSecondary,
                                  ),
                                ),
                                // Player 2
                                Column(
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        AppAvatar(
                                          name: p2?.displayName ?? 'Player 2',
                                          customDimension: 56,
                                        ),
                                        if (p2Won && !isDraw)
                                          Positioned(
                                            top: -8,
                                            right: -8,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: colors.warning,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.emoji_events_rounded,
                                                size: 14,
                                                color: Colors.black,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      p2?.displayName ?? 'Player 2',
                                      style: typography.body.bold,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${p2?.score ?? 0} pts',
                                      style: typography.title2.bold.copyWith(
                                        color: p2Won
                                            ? colors.success
                                            : colors.secondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (p2Won && !isDraw)
                                      const AppBadge(
                                        label: '🏆 Winner',
                                        variant: AppBadgeVariant.success,
                                      )
                                    else if (isDraw)
                                      const AppBadge(
                                        label: '⚔️ Tied',
                                        variant: AppBadgeVariant.warning,
                                      )
                                    else
                                      const AppBadge(
                                        label: 'Runner-up',
                                        variant: AppBadgeVariant.secondary,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 32),

                    // Rematch and Navigation Controls
                    QuizDuelRematchSection(
                      state: state,
                      opponent: opponent,
                      forfeitByRival: forfeitByRival,
                      onAcceptRematch: onAcceptRematch,
                      onDeclineRematch: onDeclineRematch,
                      onCancelRematchRequest: onCancelRematchRequest,
                      onRequestRematch: onRequestRematch,
                      onRematchWithAi: onRematchWithAi,
                      onFindNewRival: onFindNewRival,
                      onShareDuel: onShareDuel,
                      onReturnToDashboard: onReturnToDashboard,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
