import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Deck completion celebration view in InRoomDeckStudyWorkspace
/// showing congratulations trophy and actions to review again or switch decks.
class WorkspaceDeckCompletedView extends StatelessWidget {
  const WorkspaceDeckCompletedView({
    required this.deckTitle,
    required this.totalCards,
    required this.onReviewAgainTap,
    required this.onSwitchDeckTap,
    super.key,
  });

  final String deckTitle;
  final int totalCards;
  final VoidCallback onReviewAgainTap;
  final VoidCallback onSwitchDeckTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.recallEasy.withAlpha(isDark ? 50 : 30),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 54,
                color: colors.recallEasy,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deck Round Complete! 🎉',
              style: typography.title2.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You reviewed all $totalCards cards in "$deckTitle" alongside your pod.',
              style: typography.body.medium.copyWith(
                color: colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShrinkableButton(
                  onTap: onReviewAgainTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceTertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.replay_rounded,
                          size: 16,
                          color: colors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Review Again',
                          style: typography.body.bold.copyWith(
                            color: colors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ShrinkableButton(
                  onTap: onSwitchDeckTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sync_rounded,
                          size: 16,
                          color: colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Switch Deck',
                          style: typography.body.bold.copyWith(
                            color: colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
