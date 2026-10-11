import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/quiz/domain/entities/quiz_duel_entity.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_duel_state.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Rematch buttons, AI fallback triggers, and dashboard navigation options
/// displayed at the bottom of the duel scoreboard.
class QuizDuelRematchSection extends StatelessWidget {
  const QuizDuelRematchSection({
    required this.state,
    required this.opponent,
    required this.forfeitByRival,
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
  final QuizDuelParticipant opponent;
  final bool forfeitByRival;
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

    if (state.didOpponentRequestRematch) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.primary.withAlpha(120),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${opponent.displayName} challenged you to a rematch!',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Accept to immediately launch into a new duel with fresh questions.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Accept Rematch! ⚔️',
            isLoading: state.isRematchLoading,
            onPressed: onAcceptRematch,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Decline / Return to Dashboard',
            variant: AppButtonVariant.ghost,
            onPressed: onDeclineRematch,
          ),
        ],
      );
    }

    if (state.didIRequestRematch) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfacePrimary,
              borderRadius: BorderRadius.circular(AppRadius.panel),
              border: Border.all(
                color: colors.surfaceBorder.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waiting for ${opponent.displayName} to accept...',
                        style: typography.body.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your rematch challenge was sent over live arena.',
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            text: 'Play with AI Bot Now ⚡',
            onPressed: onRematchWithAi,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Cancel Rematch Request',
            variant: AppButtonVariant.secondary,
            onPressed: onCancelRematchRequest,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Return to Dashboard',
            variant: AppButtonVariant.ghost,
            onPressed: onReturnToDashboard,
          ),
        ],
      );
    }

    if (forfeitByRival) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            text: 'Find New Rival ⚔️',
            isLoading: state.isRematchLoading,
            onPressed: onFindNewRival,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Practice Solo with AI ⚡',
            variant: AppButtonVariant.secondary,
            onPressed: onRematchWithAi,
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Return to Dashboard',
            variant: AppButtonVariant.ghost,
            onPressed: onReturnToDashboard,
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppButton(
          text: state.isOpponentAi
              ? 'Rematch with ${opponent.displayName} ⚔️'
              : 'Rematch Rival ⚔️',
          isLoading: state.isRematchLoading,
          onPressed: onRequestRematch,
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Share Duel & Invite 🚀',
          variant: AppButtonVariant.secondary,
          onPressed: onShareDuel,
        ),
        const SizedBox(height: 12),
        AppButton(
          text: 'Return to Dashboard',
          variant: AppButtonVariant.ghost,
          onPressed: onReturnToDashboard,
        ),
      ],
    );
  }
}
