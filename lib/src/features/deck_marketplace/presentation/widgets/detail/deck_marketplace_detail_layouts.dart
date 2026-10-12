import 'package:flutter/material.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_card_preview_section.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_info_panel.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_inline_clone_button.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_rating_and_delete_section.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_stats_row.dart';

class DeckMarketplaceCompactDetailLayout extends StatelessWidget {
  const DeckMarketplaceCompactDetailLayout({
    required this.deck,
    required this.isDark,
    required this.isOwner,
    required this.isAlreadyCloned,
    required this.currentRating,
    required this.userRating,
    required this.onRate,
    required this.isDeleting,
    required this.onDelete,
    super.key,
  });

  final SharedDeckEntity deck;
  final bool isDark;
  final bool isOwner;
  final bool isAlreadyCloned;
  final double currentRating;
  final int? userRating;
  final ValueChanged<int> onRate;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DeckMarketplaceInfoPanel(deck: deck, isDark: isDark),
        const SizedBox(height: 16),
        DeckMarketplaceStatsRow(deck: deck, rating: currentRating),
        const SizedBox(height: 16),
        DeckMarketplaceRatingSection(
          deck: deck,
          isOwner: isOwner,
          isAlreadyCloned: isAlreadyCloned,
          currentRating: currentRating,
          userRating: userRating,
          onRate: onRate,
        ),
        if (isOwner) ...[
          const SizedBox(height: 12),
          DeckMarketplaceOwnerDeleteButton(
            onDelete: onDelete,
            isDeleting: isDeleting,
          ),
        ],
        const SizedBox(height: 20),
        DeckMarketplaceCardPreviewSection(
          deck: deck,
          isDark: isDark,
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class DeckMarketplaceWideDetailLayout extends StatelessWidget {
  const DeckMarketplaceWideDetailLayout({
    required this.deck,
    required this.isDark,
    required this.isOwner,
    required this.currentRating,
    required this.userRating,
    required this.onRate,
    required this.isDeleting,
    required this.onDelete,
    required this.isCloning,
    required this.isAlreadyCloned,
    required this.onClone,
    super.key,
  });

  final SharedDeckEntity deck;
  final bool isDark;
  final bool isOwner;
  final double currentRating;
  final int? userRating;
  final ValueChanged<int> onRate;
  final bool isDeleting;
  final VoidCallback onDelete;
  final bool isCloning;
  final bool isAlreadyCloned;
  final VoidCallback onClone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: deck info + stats + rating + primary CTA + owner actions
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DeckMarketplaceInfoPanel(deck: deck, isDark: isDark),
              const SizedBox(height: 16),
              DeckMarketplaceStatsRow(deck: deck, rating: currentRating),
              const SizedBox(height: 16),
              DeckMarketplaceRatingSection(
                deck: deck,
                isOwner: isOwner,
                isAlreadyCloned: isAlreadyCloned,
                currentRating: currentRating,
                userRating: userRating,
                onRate: onRate,
              ),
              const SizedBox(height: 16),
              DeckMarketplaceInlineCloneButton(
                isCloning: isCloning,
                isAlreadyCloned: isAlreadyCloned,
                onClone: onClone,
              ),
              if (isOwner) ...[
                const SizedBox(height: 12),
                DeckMarketplaceOwnerDeleteButton(
                  onDelete: onDelete,
                  isDeleting: isDeleting,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 20),
        // Right: card preview panel + flashcards breakdown
        Expanded(
          flex: 5,
          child: DeckMarketplaceCardPreviewSection(
            deck: deck,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}
