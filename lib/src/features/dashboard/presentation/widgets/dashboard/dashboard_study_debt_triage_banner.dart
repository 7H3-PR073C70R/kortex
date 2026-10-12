import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/dashboard/domain/entities/study_deck_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Real-time cohort accountability and peer co-presence indicator
/// Overcomes backlog avoidance / study debt paralysis through gentle FSRS triage
class DashboardStudyDebtTriageBanner extends StatelessWidget {
  const DashboardStudyDebtTriageBanner({
    required this.deck,
    super.key,
  });

  final StudyDeckEntity deck;

  void _startSprint(BuildContext context, int count) {
    AppFeedback.medium();
    unawaited(
      context.router.push(
        StudySessionRoute(deckId: 'sprint:$count:${deck.id}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.warning.withAlpha(isDark ? 50 : 25),
            colors.surfaceSecondary.withAlpha(isDark ? 160 : 240),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusPanel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.warning.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.healing_rounded,
                  color: colors.warning,
                  size: 20,
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
                            l10n.backlogTriageTitle,
                            overflow: TextOverflow.ellipsis,
                            style: typography.caption.bold.copyWith(
                              color: colors.warning,
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
                            color: colors.warning.withAlpha(30),
                            borderRadius: AppRadius.radiusBadge,
                          ),
                          child: Text(
                            l10n.dashboardDueCount(deck.dueCards),
                            style: typography.caption.bold.copyWith(
                              color: colors.warning,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.backlogTriageSubtitle,
                      style: typography.subhead.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.backlogTriageBody(deck.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.caption.regular.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Sprint Triage:',
                style: typography.caption.bold.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DashboardSprintModeChip(
                      label: '5 Cards',
                      onTap: () => _startSprint(context, 5),
                    ),
                    const SizedBox(width: 6),
                    DashboardSprintModeChip(
                      label: '10 Cards',
                      isRecommended: true,
                      onTap: () => _startSprint(context, 10),
                    ),
                    const SizedBox(width: 6),
                    DashboardSprintModeChip(
                      label: '15 Cards',
                      onTap: () => _startSprint(context, 15),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardSprintModeChip extends StatelessWidget {
  const DashboardSprintModeChip({
    required this.label,
    required this.onTap,
    this.isRecommended = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;

    return Expanded(
      child: ShrinkableButton(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isRecommended
                ? colors.warning
                : colors.warning.withAlpha(30),
            borderRadius: AppRadius.radiusBadge,
            border: Border.all(
              color: colors.warning.withAlpha(isRecommended ? 255 : 80),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: typography.caption.bold.copyWith(
              color: isRecommended ? colors.white : colors.warning,
              fontSize: 10.5,
            ),
          ),
        ),
      ),
    );
  }
}
