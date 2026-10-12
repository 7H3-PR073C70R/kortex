import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_tour_keys.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Prominent Today hero banner presenting review workload or celebration.
class DecksTodayHeroBanner extends StatelessWidget {
  const DecksTodayHeroBanner({
    required this.allDecks,
    required this.onBrowseAll,
    super.key,
  });

  final List<DeckEntity> allDecks;
  final VoidCallback onBrowseAll;

  static const int _secondsPerCard = 8;

  @override
  Widget build(BuildContext context) {
    if (allDecks.isEmpty) return const SizedBox.shrink();

    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;
    final reduceMotion = context.reduceMotion;

    final totalDue = allDecks.fold<int>(0, (sum, d) => sum + d.dueCards);
    final hasDue = totalDue > 0;
    final dueMinutes = (totalDue * _secondsPerCard / 60).ceil().clamp(1, 999);

    final dueDecks = allDecks.where((d) => d.dueCards > 0).toList();
    final reviewDeckId = dueDecks.length == 1 ? dueDecks.first.id : 'all';

    final Widget hero = Container(
      key: AppTourKeys.decksTodayHeroKey,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [colors.surfaceSecondary, colors.surfaceTertiary]
              : [colors.surfacePrimary, colors.surfaceSecondary],
        ),
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: hasDue
              ? colors.primary.withValues(alpha: 0.35)
              : colors.success.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.black.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, heroConstraints) {
          final isWide = heroConstraints.maxWidth >= 540;

          final headerInfo = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (hasDue ? colors.primary : colors.success).withValues(
                    alpha: 0.18,
                  ),
                ),
                child: Icon(
                  hasDue
                      ? Icons.school_rounded
                      : Icons.check_circle_outline_rounded,
                  color: hasDue ? colors.primary : colors.success,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasDue
                          ? l10n.decksHeroWaitingTitle(totalDue)
                          : l10n.decksHeroAllCaughtUp,
                      style: typography.body.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 16.5,
                        height: 1.25,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDue
                          ? l10n.decksHeroEstimate(dueMinutes)
                          : l10n.decksHeroAllCaughtUpSubtitle,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          final ctaButton = hasDue
              ? ShrinkableButton(
                  key: AppTourKeys.decksHeroStartBtnKey,
                  onTap: () {
                    AppFeedback.selection();
                    unawaited(
                      context.router.push(
                        StudySessionRoute(deckId: reviewDeckId),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.primary, colors.syllabotAccent],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      boxShadow: [
                        BoxShadow(
                          color: colors.black.withAlpha(isDark ? 45 : 25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Semantics(
                      button: true,
                      label: l10n.decksHeroReviewCta(totalDue),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.decksHeroReviewCta(totalDue),
                            style: typography.caption.bold.copyWith(
                              color: colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ShrinkableButton(
                  onTap: () {
                    unawaited(HapticFeedback.lightImpact());
                    onBrowseAll();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? colors.white.withValues(alpha: 0.08)
                          : colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(
                        color: colors.surfaceBorder.withValues(alpha: 0.6),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      l10n.decksHeroBrowseDecks,
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );

          if (isWide) {
            return Row(
              children: [
                Expanded(child: headerInfo),
                const SizedBox(width: 16),
                ctaButton,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerInfo,
              const SizedBox(height: 14),
              SizedBox(width: double.infinity, child: ctaButton),
            ],
          );
        },
      ),
    );

    if (reduceMotion) return hero;

    return hero
        .animate()
        .fadeIn(duration: 250.ms, curve: Curves.easeOut)
        .scale(
          begin: const Offset(0.97, 0.97),
          end: const Offset(1, 1),
          duration: 250.ms,
          curve: Curves.easeOutQuint,
        )
        .slideY(
          begin: 0.04,
          end: 0,
          duration: 250.ms,
          curve: Curves.easeOutQuint,
        );
  }
}
