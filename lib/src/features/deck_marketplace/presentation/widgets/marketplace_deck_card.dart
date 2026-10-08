import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class MarketplaceDeckCard extends StatelessWidget {
  const MarketplaceDeckCard({
    required this.deck,
    required this.onTap,
    this.onCloneTap,
    this.isSelected = false,
    this.isAlreadyCloned = false,
    this.margin,
    super.key,
  });

  final SharedDeckEntity deck;
  final VoidCallback onTap;
  final VoidCallback? onCloneTap;
  final bool isSelected;
  final bool isAlreadyCloned;
  final EdgeInsetsGeometry? margin;

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
      child: ShrinkableButton(
        onTap: onTap,
        shrinkScale: 0.985,
        child: PlatformHoverBuilder(
          builder: (context, isHovered, child) {
            return AnimatedContainer(
              duration: AppMotion.snappy,
              margin: margin,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? colors.surfaceSecondary.withAlpha(240)
                          : colors.surfacePrimary)
                    : (isHovered
                          ? (isDark
                                ? colors.surfaceSecondary.withAlpha(220)
                                : colors.surfacePrimary)
                          : (isDark ? colors.surfaceSecondary : colors.surfacePrimary)),
                borderRadius: AppRadius.radiusPanel,
                border: Border.all(
                  color: isSelected
                      ? colors.primary
                      : (isHovered
                            ? colors.primary.withAlpha(isDark ? 140 : 100)
                            : colors.primary.withAlpha(isDark ? 40 : 25)),
                  width: isSelected ? 2.0 : (isHovered ? 1.5 : 1.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? colors.primary.withAlpha(isDark ? 80 : 40)
                        : colors.black.withAlpha(
                            isDark ? (isHovered ? 45 : 20) : (isHovered ? 15 : 6),
                          ),
                    blurRadius: isSelected ? 14 : (isHovered ? 12 : 6),
                    offset: Offset(0, isSelected ? 3 : (isHovered ? 4 : 2)),
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
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Text(
                              deck.category.toUpperCase(),
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.recallEasy.withAlpha(
                                isDark ? 40 : 20,
                              ),
                              borderRadius: AppRadius.radiusBadge,
                              border: Border.all(
                                color: colors.recallEasy.withAlpha(
                                  isDark ? 90 : 60,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  size: 11,
                                  color: colors.recallEasy,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Verified Vault',
                                  style: typography.caption.bold.copyWith(
                                    color: colors.recallEasy,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: colors.warning,
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
                const SizedBox(height: 10),

                // Deck Title
                Text(
                  deck.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.subhead.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),

                // Subject & Creator
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${deck.subject} • by ${deck.ownerName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    if (deck.rating >= 4.5 || deck.downloadsCount >= 10)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.warning.withAlpha(25),
                          borderRadius: AppRadius.radiusMicro,
                          border: Border.all(
                            color: colors.warning.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 11,
                              color: colors.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Mastery Contributor',
                              style: typography.caption.bold.copyWith(
                                color: colors.warning,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

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
                    if (isAlreadyCloned)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: colors.recallEasy.withAlpha(isDark ? 35 : 20),
                          borderRadius: AppRadius.radiusCard,
                          border: Border.all(
                            color: colors.recallEasy.withAlpha(isDark ? 90 : 60),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: colors.recallEasy,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'In Library',
                              style: typography.caption.bold.copyWith(
                                color: colors.recallEasy,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      PlatformHoverBuilder(
                        builder: (context, isBtnHovered, child) {
                          return ShrinkableButton(
                            onTap: onCloneTap,
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isBtnHovered
                                    ? colors.primary.withAlpha(isDark ? 80 : 50)
                                    : colors.primary.withAlpha(isDark ? 50 : 30),
                                borderRadius: AppRadius.radiusCard,
                                border: Border.all(
                                  color: isBtnHovered
                                      ? colors.primary
                                      : colors.primary.withAlpha(100),
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
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
}
