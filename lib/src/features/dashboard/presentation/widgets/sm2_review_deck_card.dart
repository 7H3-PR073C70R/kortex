import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

class Sm2ReviewDeckCard extends StatelessWidget {
  const Sm2ReviewDeckCard({
    required this.deck,
    this.isHero = false,
    super.key,
  });

  final StudyDeckEntity deck;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final retentionPercent = (deck.retentionRate * 100).toInt();

    return Semantics(
      button: true,
      label: '${deck.title}. ${l10n.dashboardDueCount(deck.dueCards)}. '
          '${l10n.dashboardMemoryRetention}: $retentionPercent%.',
      child: ShrinkableButton(
        onTap: () {
          unawaited(HapticFeedback.lightImpact());
          unawaited(context.router.push(StudySessionRoute(deckId: deck.id)));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: isHero
                    ? (isDark
                        ? colors.surfaceSecondary.withAlpha(190)
                        : colors.surfacePrimary.withAlpha(230))
                    : (isDark
                        ? colors.surfaceSecondary.withAlpha(150)
                        : colors.surfacePrimary.withAlpha(200)),
                border: Border.all(
                  color: isHero
                      ? colors.primary.withAlpha(isDark ? 130 : 90)
                      : (isDark
                          ? colors.surfaceBorderHighlight.withAlpha(70)
                          : colors.surfaceBorder.withAlpha(140)),
                  width: isHero ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHero
                        ? colors.primary.withAlpha(isDark ? 50 : 25)
                        : Colors.black.withAlpha(isDark ? 40 : 10),
                    blurRadius: isHero ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Category Tag & Due Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withAlpha(isDark ? 50 : 25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          deck.subject.toUpperCase(),
                          style: typography.caption.bold.copyWith(
                            color: colors.primary,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      if (deck.isDueToday)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: colors.error.withAlpha(isDark ? 50 : 25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: colors.error.withAlpha(120),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.bolt_rounded,
                                size: 12,
                                color: colors.error,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                l10n.dashboardDueCount(deck.dueCards),
                                style: typography.caption.bold.copyWith(
                                  color: colors.error,
                                  fontSize: 10.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
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
                  const SizedBox(height: 14),

                  // Retention Rate Bar & Metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.dashboardMemoryRetention,
                        style: typography.footnote.regular.copyWith(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '$retentionPercent%',
                        style: typography.footnote.bold.copyWith(
                          color: retentionPercent >= 85
                              ? colors.success
                              : colors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 6,
                      color: isDark
                          ? colors.surfaceBorderHighlight.withAlpha(60)
                          : colors.surfaceBorder.withAlpha(120),
                      child: Stack(
                        children: [
                          FractionallySizedBox(
                            widthFactor: deck.retentionRate.clamp(0.05, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colors.primary,
                                    colors.syllabotAccent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Bottom Action Strip
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: isDark
                                ? colors.textSecondary
                                : colors.textPrimary.withAlpha(180),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.dashboardEstimatedMinutes(
                              deck.estimatedMinutes,
                            ),
                            style: typography.caption.medium.copyWith(
                              color: isDark
                                  ? colors.textSecondary
                                  : colors.textPrimary.withAlpha(180),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            l10n.dashboardReviewDeck,
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
