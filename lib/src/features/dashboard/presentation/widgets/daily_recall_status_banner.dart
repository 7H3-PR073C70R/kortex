import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/dashboard/domain/entities/dashboard_feed_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Glass "All caught up! SYNCED" banner — mirrors the Stitch DailyStatusRecallBanner.
/// Shows due-card count + deck title when reviews are pending, and is 1-tap actionable.
class DailyRecallStatusBanner extends StatelessWidget {
  const DailyRecallStatusBanner({
    required this.feed,
    super.key,
  });

  final DashboardFeedEntity feed;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;
    final l10n = context.l10n;

    final hasDueCards = feed.dueStudyDecks.any((d) => d.dueCards > 0);
    final topDueDeck = hasDueCards
        ? feed.dueStudyDecks.firstWhere((d) => d.dueCards > 0)
        : null;

    // Design uses emerald for the synced state; amber mirrors it for due cards.
    final accent = hasDueCards ? neural.amber : neural.emerald;
    final accent400 = hasDueCards ? neural.amber400 : neural.emerald400;
    final accent300 = hasDueCards ? neural.amber300 : neural.emerald300;

    return Semantics(
      button: true,
      label: hasDueCards
          ? '${l10n.dashboardDueCount(topDueDeck!.dueCards)}. ${l10n.dashboardReviewDeck}. ${topDueDeck.title}.'
          : '${l10n.allCaughtUpTitle}. ${l10n.allCaughtUpSubtitle}.',
      child: PlatformHoverBuilder(
        builder: (context, isHovered, _) {
          return ShrinkableButton(
            onTap: () {
              AppFeedback.selection();
              if (hasDueCards && topDueDeck != null) {
                unawaited(
                  context.router.push(
                    StudySessionRoute(deckId: topDueDeck.id),
                  ),
                );
              } else {
                try {
                  AutoTabsRouter.of(context).setActiveIndex(1);
                } on Object catch (e, st) {
                  AppLogger.debug('[DailyRecallStatusBanner] AutoTabsRouter not found, pushing DecksRoute: $e', error: e, stackTrace: st);
                  unawaited(context.router.push(const DecksRoute()));
                }
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: AppMotion.snappy,
                      curve: AppMotion.easeOutCubic,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isHovered
                            ? neural.glassPanel.withAlpha(240)
                            : neural.glassPanel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isHovered
                              ? accent.withAlpha(160)
                              : accent.withAlpha(77),
                          width: isHovered ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          if (isHovered)
                            BoxShadow(
                              color: accent.withAlpha(40),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            key: AppTourKeys.reviewQueueCountKey,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withAlpha(51),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: accent400.withAlpha(77),
                              ),
                            ),
                            child: Icon(
                              hasDueCards
                                  ? Icons.hourglass_top_rounded
                                  : Icons.check_circle_rounded,
                              color: accent400,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        hasDueCards
                                            ? l10n.dashboardDueCount(
                                                topDueDeck!.dueCards,
                                              )
                                            : l10n.allCaughtUpTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: typography.callout.bold.copyWith(
                                          color: neural.slate100,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent.withAlpha(51),
                                        borderRadius: BorderRadius.circular(99),
                                        border: Border.all(
                                          color: accent.withAlpha(77),
                                        ),
                                      ),
                                      child: Text(
                                        hasDueCards
                                            ? l10n.dashboardReviewDeck
                                                  .toUpperCase()
                                            : 'SYNCED',
                                        style: typography.caption.bold.copyWith(
                                          color: accent300,
                                          fontSize: 10,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  hasDueCards
                                      ? topDueDeck!.title
                                      : l10n.allCaughtUpSubtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: typography.caption.regular.copyWith(
                                    color: neural.slate300.withAlpha(204),
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedSlide(
                            duration: AppMotion.snappy,
                            offset: isHovered
                                ? const Offset(0.12, 0)
                                : Offset.zero,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withAlpha(isHovered ? 45 : 25),
                              ),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                color: isHovered
                                    ? accent300
                                    : accent400.withAlpha(200),
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Ambient accent lighting glow (top-right, clipped by panel)
                    Positioned(
                      right: -32,
                      top: -32,
                      child: IgnorePointer(
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                accent.withAlpha(isHovered ? 60 : 38),
                                accent.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
