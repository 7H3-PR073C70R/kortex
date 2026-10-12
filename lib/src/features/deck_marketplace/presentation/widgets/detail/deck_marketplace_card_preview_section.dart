import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_card_preview_carousel.dart';
import 'package:kortex/src/features/decks/domain/entities/flashcard_entity.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/latex_rich_viewer.dart';

class DeckMarketplaceCardPreviewSection extends StatelessWidget {
  const DeckMarketplaceCardPreviewSection({
    required this.deck,
    required this.isDark,
    super.key,
  });

  final SharedDeckEntity deck;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    final displayCards = deck.cards.isNotEmpty
        ? deck.cards.take(5).toList()
        : [
            FlashcardEntity(
              id: 'preview_1',
              deckId: 'preview',
              front: 'Key concept: Essential foundations in ${deck.subject}',
              back:
                  'Comprehensive revision breakdown with memory aids and formulas.',
            ),
            FlashcardEntity(
              id: 'preview_2',
              deckId: 'preview',
              front: 'High-yield exam application in ${deck.subject}',
              back: 'Step-by-step problem resolution for top test scores.',
            ),
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_stories_rounded,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Card Preview',
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: colors.primary.withAlpha(isDark ? 40 : 20),
                borderRadius: AppRadius.radiusBadge,
              ),
              child: Text(
                '${deck.totalCards} cards total',
                style: typography.caption.bold.copyWith(
                  color: colors.primary,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a card to flip between question and answer',
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 14),

        // The interactive carousel
        DeckMarketplaceInteractiveCardPreviewCarousel(
          cards: deck.cards,
          totalCards: deck.totalCards,
          subject: deck.subject,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Flashcards List Breakdown
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceSecondary.withAlpha(140)
                : colors.surfacePrimary,
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 35 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.view_list_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Included Flashcards',
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${deck.totalCards} items',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayCards.length,
                separatorBuilder: (context, index) => Divider(
                  height: 16,
                  thickness: 0.5,
                  color: colors.surfaceBorder.withAlpha(isDark ? 40 : 25),
                ),
                itemBuilder: (context, index) {
                  final card = displayCards[index];
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 35 : 20),
                          borderRadius: AppRadius.radiusMicro,
                        ),
                        child: Text(
                          '${index + 1}',
                          style: typography.caption.bold.copyWith(
                            fontSize: 10,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LatexRichViewer(
                              text: card.front,
                              style: typography.caption.bold.copyWith(
                                color: colors.textPrimary,
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            LatexRichViewer(
                              text: card.back,
                              style: typography.caption.regular.copyWith(
                                color: colors.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
