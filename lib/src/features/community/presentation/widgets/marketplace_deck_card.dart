import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/community/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class MarketplaceDeckCard extends StatelessWidget {
  const MarketplaceDeckCard({
    required this.deck,
    required this.onTap,
    required this.onCloneTap,
    super.key,
  });

  final SharedDeckEntity deck;
  final VoidCallback onTap;
  final VoidCallback onCloneTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final semanticsLabel =
        'Marketplace Deck: ${deck.title}, '
        'Subject: ${deck.subject}, Cards: ${deck.totalCards}';

    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colors.primary.withAlpha(isDark ? 40 : 25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category tag + Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    deck.category.toUpperCase(),
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deck.rating.toStringAsFixed(1),
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Deck Title
            Text(
              deck.title,
              style: typography.title3.bold.copyWith(
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Subject & Creator
            Text(
              '${deck.subject} • by ${deck.ownerName}',
              style: typography.footnote.regular.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // Bottom Row: Stats & Clone Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.style_outlined,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${deck.totalCards} cards',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.download_rounded,
                      size: 16,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${deck.downloadsCount}',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
                ShrinkableButton(
                  onTap: onCloneTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colors.primary.withAlpha(100),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l10n.cloneDeckButton,
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
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
