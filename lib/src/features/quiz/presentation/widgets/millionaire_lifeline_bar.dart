import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/quiz/presentation/bloc/quiz_session_state.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// An interactive lifeline and status bar for the Millionaire quiz mode.
class MillionaireLifelineBar extends StatelessWidget {
  const MillionaireLifelineBar({
    required this.state,
    required this.onUseFiftyFifty,
    required this.onUseAiClue,
    required this.onUseSkipSwap,
    required this.onOpenLadder,
    required this.onWalkAway,
    this.onUseAskAudience,
    super.key,
  });

  final QuizSessionState state;
  final VoidCallback onUseFiftyFifty;
  final VoidCallback onUseAiClue;
  final VoidCallback onUseSkipSwap;
  final VoidCallback onOpenLadder;
  final VoidCallback onWalkAway;
  final VoidCallback? onUseAskAudience;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final isFiftyFiftyAvailable =
        state.isLifelineAvailable(LifelineType.fiftyFifty);
    final isAiClueAvailable = state.isLifelineAvailable(LifelineType.aiClue);
    final isAskAudienceAvailable =
        state.isLifelineAvailable(LifelineType.askAudience);
    final isSkipSwapAvailable =
        state.isLifelineAvailable(LifelineType.skipSwap);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withValues(alpha: 0.85)
            : colors.surfacePrimary.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.surfaceBorder.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tier Ladder Badge & Button
          ShrinkableButton(
            onTap: onOpenLadder,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: state.isCurrentTierSafeCheckpoint
                      ? [const Color(0xFF10B981), const Color(0xFF059669)]
                      : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (state.isCurrentTierSafeCheckpoint
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    state.isCurrentTierSafeCheckpoint
                        ? Icons.shield_rounded
                        : Icons.military_tech_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tier ${state.currentTier}/12',
                    style: typography.caption.bold.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Lifeline 1: 50:50
          _LifelinePill(
            label: '50:50',
            icon: Icons.filter_2_rounded,
            isAvailable: isFiftyFiftyAvailable,
            onTap: isFiftyFiftyAvailable ? onUseFiftyFifty : null,
          ),
          const SizedBox(width: 6),

          // Lifeline 2: AI Clue
          _LifelinePill(
            label: 'AI Clue',
            icon: Icons.auto_awesome_rounded,
            isAvailable: isAiClueAvailable,
            onTap: isAiClueAvailable ? onUseAiClue : null,
          ),
          const SizedBox(width: 6),

          // Lifeline 3: Ask Crowd
          if (onUseAskAudience != null) ...[
            _LifelinePill(
              label: 'Crowd',
              icon: Icons.groups_rounded,
              isAvailable: isAskAudienceAvailable,
              onTap: isAskAudienceAvailable ? onUseAskAudience : null,
            ),
            const SizedBox(width: 6),
          ],

          // Lifeline 4: Skip & Swap
          _LifelinePill(
            label: 'Skip',
            icon: Icons.skip_next_rounded,
            isAvailable: isSkipSwapAvailable,
            onTap: isSkipSwapAvailable ? onUseSkipSwap : null,
          ),
          const SizedBox(width: 8),

          // Walk Away Action
          ShrinkableButton(
            onTap: onWalkAway,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Tooltip(
                message: 'Bank current XP and walk away safely',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.savings_rounded,
                      color: colors.error,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Bank',
                      style: typography.footnote.bold.copyWith(
                        color: colors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LifelinePill extends StatelessWidget {
  const _LifelinePill({
    required this.label,
    required this.icon,
    required this.isAvailable,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isAvailable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Opacity(
      opacity: isAvailable ? 1.0 : 0.35,
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isAvailable
                ? colors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                : (isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isAvailable
                  ? colors.primary.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isAvailable ? colors.primary : colors.textMuted,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: typography.footnote.bold.copyWith(
                  color: isAvailable ? colors.primary : colors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
