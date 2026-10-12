import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Behavioral decision-fatigue reducer: 1-Tap Next Best Action Card
class DashboardNextBestActionCard extends StatelessWidget {
  const DashboardNextBestActionCard({
    required this.topDeck,
    super.key,
  });

  final StudyDeckEntity topDeck;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final badgeLabel = l10n.fifteenMinSprint;
    final actionTitle = l10n.dashboardReviewDeck;

    return PlatformHoverBuilder(
      builder: (context, isHovered, _) {
        return ShrinkableButton(
          onTap: () {
            AppFeedback.selection();
            unawaited(
              context.router.push(
                StudySessionRoute(deckId: 'sprint:10:${topDeck.id}'),
              ),
            );
          },
          child: AnimatedContainer(
            duration: AppMotion.snappy,
            curve: AppMotion.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withAlpha(
                    isDark ? (isHovered ? 75 : 55) : (isHovered ? 35 : 25),
                  ),
                  colors.syllabotAccent.withAlpha(
                    isDark ? (isHovered ? 55 : 40) : (isHovered ? 25 : 18),
                  ),
                ],
              ),
              borderRadius: AppRadius.radiusPanel,
              boxShadow: [
                BoxShadow(
                  color: colors.black.withAlpha(
                    isDark ? (isHovered ? 40 : 20) : (isHovered ? 15 : 8),
                  ),
                  blurRadius: isHovered ? 10 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [colors.primary, colors.syllabotAccent],
                    ),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              l10n.nextBestActionTitle,
                              overflow: TextOverflow.ellipsis,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withAlpha(30),
                              borderRadius: AppRadius.radiusBadge,
                            ),
                            child: Text(
                              badgeLabel,
                              style: typography.caption.bold.copyWith(
                                color: colors.primary,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$actionTitle: ${topDeck.title}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.subhead.bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: AppRadius.radiusBadge,
                  ),
                  child: Text(
                    l10n.startAction,
                    style: typography.caption.bold.copyWith(
                      color: colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
