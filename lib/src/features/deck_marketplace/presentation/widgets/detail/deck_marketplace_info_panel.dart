import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/deck_marketplace/domain/entities/shared_deck_entity.dart';
import 'package:kortex/src/features/deck_marketplace/presentation/widgets/detail/deck_marketplace_badges.dart';
import 'package:kortex/src/shared/widgets/app_avatar.dart';

class DeckMarketplaceInfoPanel extends StatelessWidget {
  const DeckMarketplaceInfoPanel({
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary.withAlpha(isDark ? 50 : 25),
            colors.syllabotAccent.withAlpha(isDark ? 40 : 18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusDialog,
        border: Border.all(
          color: colors.primary.withAlpha(isDark ? 60 : 35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge row — Wrap so it never overflows on small screens
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Category badge
              DeckMarketplaceBadge(
                label: deck.category.toUpperCase(),
                color: colors.primary,
                alpha: 40,
              ),
              // Verified vault badge
              DeckMarketplaceBadgeWithIcon(
                icon: Icons.verified_rounded,
                label: 'Verified Vault',
                color: colors.recallEasy,
                borderAlpha: 80,
                bgAlpha: 40,
              ),
              // Syllabus tag badge
              if (deck.syllabusTag.isNotEmpty &&
                  deck.syllabusTag != 'General')
                DeckMarketplaceEmojiTextBadge(
                  emoji: '📚',
                  label: deck.syllabusTag,
                  color: colors.syllabotAccent,
                  borderAlpha: 70,
                  bgAlpha: 35,
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            deck.title,
            style: typography.title2.bold.copyWith(
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Author row
          Row(
            children: [
              AppAvatar(
                customDimension: 22,
                name: deck.ownerName,
                backgroundColor: colors.primary.withAlpha(isDark ? 50 : 35),
                foregroundColor: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${deck.subject} • by ${deck.ownerName}',
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // XP incentive chip
          DeckMarketplaceEmojiTextBadge(
            emoji: '✨',
            label: 'Cloning awards +25 XP to ${deck.ownerName}',
            color: colors.syllabotAccent,
            bgAlpha: isDark ? 30 : 18,
          ),

          // Description
          if (deck.description != null && deck.description!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(120)
                    : colors.surfacePrimary.withAlpha(200),
                borderRadius: AppRadius.radiusCard,
                border: Border.all(
                  color: colors.primary.withAlpha(isDark ? 25 : 15),
                ),
              ),
              child: Text(
                deck.description!,
                style: typography.footnote.regular.copyWith(
                  color: colors.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
