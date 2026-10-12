import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class DeckMarketplaceRatingSection extends StatelessWidget {
  const DeckMarketplaceRatingSection({
    required this.deck,
    required this.isOwner,
    required this.isAlreadyCloned,
    required this.currentRating,
    required this.userRating,
    required this.onRate,
    super.key,
  });

  final SharedDeckEntity deck;
  final bool isOwner;
  final bool isAlreadyCloned;
  final double currentRating;
  final int? userRating;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    if (isOwner) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.primary.withAlpha(isDark ? 25 : 15),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Published by You',
                    style: typography.caption.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ratings are submitted by other community users. Distributors cannot rate their own decks.',
                    style: typography.caption.regular.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!isAlreadyCloned) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? colors.surfaceSecondary.withAlpha(120)
              : colors.surfaceSecondary.withAlpha(80),
          borderRadius: AppRadius.radiusCard,
          border: Border.all(
            color: colors.surfaceBorder.withAlpha(isDark ? 50 : 30),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Rate this Deck',
                          style: typography.caption.bold.copyWith(
                            color: colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${currentRating.toStringAsFixed(1)} ★ average',
                  style: typography.caption.bold.copyWith(
                    color: colors.warning,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Clone this deck to your library before leaving a rating.',
              style: typography.caption.regular.copyWith(
                color: colors.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                final isFilled = starValue <= currentRating.round();

                return IconButton(
                  onPressed: () => onRate(starValue),
                  iconSize: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(),
                  tooltip: 'Clone deck to rate',
                  icon: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                    color: colors.warning.withAlpha(80),
                  ),
                );
              }),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 35 : 20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 16,
                      color: colors.warning,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        userRating != null ? 'Your Rating' : 'Rate this Deck',
                        style: typography.caption.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${currentRating.toStringAsFixed(1)} ★ average',
                style: typography.caption.bold.copyWith(
                  color: colors.warning,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starValue = index + 1;
              final isFilled = (userRating != null && starValue <= userRating!) ||
                  (userRating == null && starValue <= currentRating.round());

              return IconButton(
                onPressed: () => onRate(starValue),
                iconSize: 28,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
                icon: Icon(
                  isFilled ? Icons.star_rounded : Icons.star_border_rounded,
                  color: colors.warning,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class DeckMarketplaceOwnerDeleteButton extends StatelessWidget {
  const DeckMarketplaceOwnerDeleteButton({
    required this.onDelete,
    required this.isDeleting,
    super.key,
  });

  final VoidCallback onDelete;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return PlatformHoverBuilder(
      builder: (context, isHovered, child) {
        return ShrinkableButton(
          onTap: isDeleting ? null : onDelete,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colors.error.withAlpha(isHovered ? 35 : 20),
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: colors.error.withAlpha(isHovered ? 120 : 80),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isDeleting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.error,
                    ),
                  )
                else ...[
                  Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: colors.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delete Deck from Marketplace',
                    style: typography.caption.bold.copyWith(
                      color: colors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
