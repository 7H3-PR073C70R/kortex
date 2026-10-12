import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/presentation/widgets/create_deck/draft_card.dart';

/// Scrollable list displaying uncommitted flashcards added to the deck.
class CreateDeckCardsRiver extends StatelessWidget {
  const CreateDeckCardsRiver({
    required this.cards,
    required this.onClearAll,
    required this.onDeleteCard,
    super.key,
  });

  final List<DraftCard> cards;
  final VoidCallback onClearAll;
  final ValueChanged<int> onDeleteCard;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cards in Deck (${cards.length})',
              style: typography.callout.bold.copyWith(
                color: colors.textPrimary,
                fontSize: 15,
              ),
            ),
            if (cards.isNotEmpty)
              TextButton(
                onPressed: () {
                  AppFeedback.light();
                  onClearAll();
                },
                child: Text(
                  'Clear All',
                  style: typography.caption.bold.copyWith(
                    color: colors.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (cards.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 24,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(60)
                  : colors.surfacePrimary,
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(80),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.style_outlined,
                  size: 28,
                  color: colors.textMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  'No flashcards in this deck yet',
                  style: typography.caption.bold.copyWith(
                    color: colors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add cards manually or generate them with AI above.',
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final card = cards[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(100)
                      : colors.surfacePrimary,
                  borderRadius: AppRadius.radiusCard,
                  border: Border.all(
                    color: colors.surfaceBorder.withAlpha(80),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: colors.primary.withAlpha(30),
                        borderRadius: AppRadius.radiusBadge,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.front,
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            card.back,
                            style: typography.footnote.regular.copyWith(
                              color: colors.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: colors.error.withAlpha(180),
                      ),
                      onPressed: () {
                        AppFeedback.light();
                        onDeleteCard(index);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
