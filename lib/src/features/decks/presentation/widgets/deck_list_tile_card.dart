import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class DeckListTileCard extends StatelessWidget {
  const DeckListTileCard({
    required this.deck,
    super.key,
  });

  final DeckEntity deck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final masteryPercent = (deck.masteryRate * 100).toInt();

    return Semantics(
      button: true,
      label: '${deck.title}. ${deck.subject}. '
          '${l10n.decksTotalCards(deck.totalCards)}. '
          '${l10n.decksDueBadge(deck.dueCards)}.',
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(
            context.router.push(StudySessionRoute(deckId: deck.id)),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isDark
                    ? colors.surfaceSecondary.withAlpha(160)
                    : colors.surfacePrimary.withAlpha(215),
                border: Border.all(
                  color: deck.hasDueCards
                      ? colors.primary.withAlpha(isDark ? 110 : 70)
                      : (isDark
                          ? colors.surfaceBorderHighlight.withAlpha(70)
                          : colors.surfaceBorder.withAlpha(130)),
                  width: deck.hasDueCards ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Tags Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          deck.subject.toUpperCase(),
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (deck.hasDueCards)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.error.withAlpha(isDark ? 45 : 20),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.error.withAlpha(100),
                            ),
                          ),
                          child: Text(
                            l10n.decksDueBadge(deck.dueCards),
                            style: typography.caption.bold.copyWith(
                              color: colors.error,
                              fontSize: 10.5,
                            ),
                          ),
                        )
                      else
                        Text(
                          l10n.decksTotalCards(deck.totalCards),
                          style: typography.footnote.regular.copyWith(
                            color: colors.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    deck.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: typography.callout.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 15.5,
                      height: 1.3,
                    ),
                  ),
                  if (deck.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      deck.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.footnote.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Mastery Rate & Action Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_graph_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.decksMasteryPercent(masteryPercent),
                            style: typography.footnote.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            l10n.decksStartSession,
                            style: typography.caption.bold.copyWith(
                              color: colors.primary,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: colors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
