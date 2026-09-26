import 'dart:async';
import 'dart:ui';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Dashboard active recall deck card powered by FSRS-6 memory scheduling.
class FsrsReviewDeckCard extends StatelessWidget {
  const FsrsReviewDeckCard({
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
    final effectiveRadius = isHero ? AppRadius.panel : AppRadius.card;

    return Semantics(
      button: true,
      label:
          '${deck.title}. ${l10n.dashboardDueCount(deck.dueCards)}. '
          '${l10n.dashboardMemoryRetention}: $retentionPercent%.',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, _) {
          return ShrinkableButton(
            onTap: () {
              unawaited(HapticFeedback.lightImpact());
              unawaited(
                context.router.push(StudySessionRoute(deckId: deck.id)),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(effectiveRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: AnimatedContainer(
                  duration: AppMotion.snappy,
                  curve: AppMotion.easeOutCubic,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(effectiveRadius),
                    color: isHero
                        ? (isDark
                              ? colors.surfaceSecondary.withAlpha(
                                  isHovered ? 220 : 190,
                                )
                              : colors.surfacePrimary.withAlpha(
                                  isHovered ? 250 : 230,
                                ))
                        : (isDark
                              ? colors.surfaceSecondary.withAlpha(
                                  isHovered ? 180 : 150,
                                )
                              : colors.surfacePrimary.withAlpha(
                                  isHovered ? 225 : 200,
                                )),
                    border: isHero
                        ? Border.all(
                            color: isHovered
                                ? colors.primary.withAlpha(isDark ? 160 : 120)
                                : colors.primary.withAlpha(isDark ? 110 : 80),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: colors.black.withAlpha(
                          isDark
                              ? (isHovered ? 50 : 35)
                              : (isHovered ? 20 : 10),
                        ),
                        blurRadius: isHovered ? 14 : 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        <Widget>[
                              // Top Row: Category Tag & Due Badge
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(
                                        isDark ? 50 : 25,
                                      ),
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
                                        color: colors.error.withAlpha(
                                          isDark ? 50 : 25,
                                        ),
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
                                            l10n.dashboardDueCount(
                                              deck.dueCards,
                                            ),
                                            style: typography.caption.bold
                                                .copyWith(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                      ? colors.surfaceBorderHighlight.withAlpha(
                                          60,
                                        )
                                      : colors.surfaceBorder.withAlpha(120),
                                  child: Stack(
                                    children: [
                                      FractionallySizedBox(
                                        widthFactor: deck.retentionRate.clamp(
                                          0.05,
                                          1.0,
                                        ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.timer_outlined,
                                        size: 13,
                                        color: isDark
                                            ? colors.textSecondary
                                            : colors.textPrimary.withAlpha(180),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        l10n.dashboardEstimatedMinutes(
                                          deck.estimatedMinutes,
                                        ),
                                        style: typography.caption.medium
                                            .copyWith(
                                              color: isDark
                                                  ? colors.textSecondary
                                                  : colors.textPrimary
                                                        .withAlpha(180),
                                              fontSize: 11.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                  if (deck.dueCards > 15)
                                    GestureDetector(
                                      onTap: () {
                                        unawaited(HapticFeedback.lightImpact());
                                        unawaited(
                                          context.router.push(
                                            StudySessionRoute(deckId: deck.id),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withAlpha(
                                            isDark ? 50 : 25,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: colors.primary.withAlpha(80),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flash_on_rounded,
                                              size: 11,
                                              color: colors.primary,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              'Sprint',
                                              style: typography.caption.bold
                                                  .copyWith(
                                                    color: colors.primary,
                                                    fontSize: 10.5,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          unawaited(HapticFeedback.lightImpact());
                                          unawaited(
                                            context.router.push(
                                              StudySessionRoute(
                                                deckId: 'quick5:${deck.id}',
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.primary.withAlpha(25),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: colors.primary.withAlpha(60),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.bolt_rounded,
                                                size: 11,
                                                color: colors.primary,
                                              ),
                                              const SizedBox(width: 2),
                                              Text(
                                                'Quick 5',
                                                style: typography.caption.bold.copyWith(
                                                  color: colors.primary,
                                                  fontSize: 10.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.dashboardReviewDeck,
                                        style: typography.caption.bold.copyWith(
                                          color: colors.primary,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 13,
                                        color: colors.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ]
                            .animate(interval: 40.ms)
                            .fadeIn(duration: 350.ms)
                            .slideY(
                              begin: 0.05,
                              end: 0,
                              curve: Curves.easeOutQuint,
                            ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
