import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_cubit.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/shared/widgets/gratification_celebration_overlay.dart';

/// Helper coordinating the post-duel victory / defeat celebration overlay.
class QuizDuelCelebrationCoordinator {
  QuizDuelCelebrationCoordinator._();

  /// Displays the full-screen gratification celebration overlay based on duel state outcomes.
  static void showCelebration({
    required BuildContext context,
    required QuizDuelState state,
    required QuizDuelCubit cubit,
  }) {
    final isWinner = state.isWinner;
    final isDraw = state.isDraw;
    final isForfeit = state.match?.isForfeit ?? false;
    final forfeitByRival =
        isForfeit && state.match?.forfeitUserId != state.currentUserId;
    final myScore = state.myParticipant?.score ?? 0;
    final opponentScore = state.opponentParticipant?.score ?? 0;
    final opponentName = state.opponentParticipant?.displayName ?? 'Rival';

    if (isWinner || forfeitByRival) {
      AppFeedback.duelVictory();
    } else if (!isDraw) {
      AppFeedback.duelDefeat();
    } else {
      AppFeedback.medium();
    }

    final String title;
    final String subtitle;
    final String emoji;
    final String badge;
    final int xp;
    final String buttonText;
    final VoidCallback? onDismissAction;

    if (forfeitByRival) {
      emoji = '🏆';
      title = 'Rival Forfeited!';
      subtitle =
          '$opponentName left the arena. You have been awarded +500 victory points!';
      badge = '🏳️ Default Victory (+500 pts)';
      xp = 200;
      buttonText = 'Return to Dashboard';
      onDismissAction = () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      };
    } else if (isWinner) {
      emoji = '🏆';
      title = 'Duel Victory!';
      subtitle =
          'Fast and accurate! You triumphed over $opponentName in the competitive arena.';
      badge = '🏆 Arena Champion';
      xp = 150;
      buttonText = 'View Scoreboard';
      onDismissAction = null;
    } else if (isDraw) {
      emoji = '⚔️';
      title = 'Even Match!';
      subtitle =
          'Incredible duel! Both you and $opponentName finished tied on points.';
      badge = '⚔️ Steel Sharpens Steel';
      xp = 80;
      buttonText = 'View Scoreboard';
      onDismissAction = null;
    } else {
      emoji = '🛡️';
      title = 'Fierce Battle!';
      subtitle = 'Close duel! Every round makes the next victory closer.';
      badge = '💪 Experience Banked';
      xp = 40;
      buttonText = 'View Scoreboard';
      onDismissAction = null;
    }

    unawaited(
      GratificationCelebrationOverlay.show(
        context,
        title: title,
        subtitle: subtitle,
        primaryStatLabel: 'Your Score',
        primaryStatValue: '$myScore pts',
        secondaryStatLabel: 'Rival',
        secondaryStatValue: isForfeit ? 'Forfeited' : '$opponentScore pts',
        tertiaryStatLabel: 'Duel XP',
        tertiaryStatValue: '+$xp',
        xpEarned: xp,
        motivationalBadge: badge,
        buttonText: buttonText,
        onDismiss: onDismissAction,
        secondaryButtonText: forfeitByRival ? null : 'Rematch Now ⚔️',
        onSecondaryAction: forfeitByRival
            ? null
            : () {
                unawaited(cubit.requestRematch());
              },
        emoji: emoji,
      ),
    );
  }
}
