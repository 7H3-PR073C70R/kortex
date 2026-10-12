import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';

class DeckMarketplaceBadge extends StatelessWidget {
  const DeckMarketplaceBadge({
    required this.label,
    required this.color,
    this.alpha = 30,
    super.key,
  });

  final String label;
  final Color color;
  final int alpha;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(alpha),
        borderRadius: AppRadius.radiusBadge,
      ),
      child: Text(
        label,
        style: typography.caption.bold.copyWith(color: color, fontSize: 11),
      ),
    );
  }
}

class DeckMarketplaceBadgeWithIcon extends StatelessWidget {
  const DeckMarketplaceBadgeWithIcon({
    required this.icon,
    required this.label,
    required this.color,
    this.bgAlpha = 30,
    this.borderAlpha = 60,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int bgAlpha;
  final int borderAlpha;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(bgAlpha),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: color.withAlpha(borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: typography.caption.bold.copyWith(
                color: color,
                fontSize: 10.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class DeckMarketplaceEmojiTextBadge extends StatelessWidget {
  const DeckMarketplaceEmojiTextBadge({
    required this.emoji,
    required this.label,
    required this.color,
    this.bgAlpha = 25,
    this.borderAlpha = 50,
    super.key,
  });

  final String emoji;
  final String label;
  final Color color;
  final int bgAlpha;
  final int borderAlpha;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(bgAlpha),
        borderRadius: AppRadius.radiusBadge,
        border: Border.all(color: color.withAlpha(borderAlpha)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: typography.caption.bold.copyWith(
                color: color,
                fontSize: 10.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
