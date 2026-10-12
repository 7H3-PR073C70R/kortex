import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';

class DeckMarketplaceStatsRow extends StatelessWidget {
  const DeckMarketplaceStatsRow({
    required this.deck,
    this.rating,
    super.key,
  });

  final SharedDeckEntity deck;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = context.isDarkMode;
    final displayRating = rating ?? deck.rating;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(160)
            : colors.surfaceSecondary.withAlpha(120),
        borderRadius: AppRadius.radiusCard,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 30 : 18),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          DeckMarketplaceStatItem(
            icon: Icons.style_outlined,
            value: '${deck.totalCards}',
            label: 'Cards',
            color: colors.primary,
          ),
          const DeckMarketplaceStatDivider(),
          DeckMarketplaceStatItem(
            icon: Icons.download_rounded,
            value: '${deck.downloadsCount}',
            label: 'Clones',
            color: colors.syllabotAccent,
          ),
          const DeckMarketplaceStatDivider(),
          DeckMarketplaceStatItem(
            icon: Icons.star_rounded,
            value: displayRating.toStringAsFixed(1),
            label: 'Rating',
            color: colors.warning,
          ),
        ],
      ),
    );
  }
}

class DeckMarketplaceStatItem extends StatelessWidget {
  const DeckMarketplaceStatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: typography.subhead.bold.copyWith(color: colors.textPrimary),
        ),
        Text(
          label,
          style: typography.caption.regular.copyWith(
            color: colors.textSecondary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class DeckMarketplaceStatDivider extends StatelessWidget {
  const DeckMarketplaceStatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: 1,
      height: 36,
      color: colors.surfaceBorder.withAlpha(context.isDarkMode ? 60 : 40),
    );
  }
}
