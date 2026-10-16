import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/decks/presentation/widgets/fsrs_retrievability_visualizer.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_button.dart';

/// Actions section for SessionSummaryPage displaying the FSRS visualizer,
/// forward-looking next review indicator, and session completion action buttons.
class SessionSummaryActionsSection extends StatelessWidget {
  const SessionSummaryActionsSection({
    required this.deckId,
    required this.effectiveDeckId,
    required this.cardsReviewed,
    required this.retentionScore,
    required this.nextReviewInDays,
    super.key,
  });

  final String deckId;
  final String effectiveDeckId;
  final int cardsReviewed;
  final double retentionScore;
  final int nextReviewInDays;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Column(
      children: [
        // FSRS Memory Forgetting Curve Visualizer
        FsrsRetrievabilityVisualizer(
          stabilityDays: (cardsReviewed * 1.5).clamp(2.0, 30.0),
          targetRetention: retentionScore.clamp(0.70, 0.95),
          subjectTitle: 'Overall Session Memory Strength',
        ),

        // Forward-looking line: what the effort buys later.
        if (nextReviewInDays > 0) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l10n.sessionSummaryNextReview(nextReviewInDays),
                  textAlign: TextAlign.center,
                  style: typography.footnote.regular.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 32),

        // Action Buttons
        if (deckId.startsWith('sprint:')) ...[
          AppButton(
            text: '🚀 Next Focus Sprint',
            onPressed: () {
              unawaited(
                context.router.replace(
                  StudySessionRoute(deckId: deckId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          AppButton(
            text: 'Done for Now',
            variant: AppButtonVariant.outline,
            onPressed: () {
              unawaited(
                context.router.replaceAll([
                  const MainRoute(children: [DashboardRoute()]),
                ]),
              );
            },
          ),
        ] else ...[
          // Bidirectional Bridge: Checkpoint Quiz
          if (cardsReviewed > 0) ...[
            AppButton(
              text: '🎯 Validate with Checkpoint Quiz',
              onPressed: () {
                unawaited(
                  context.router.push(
                    QuizWorkspaceRoute(
                      deckId: effectiveDeckId,
                      deckTitle: 'Checkpoint Quiz',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
          ],

          // Replay Study Session Action
          AppButton(
            text: l10n.sessionSummaryStudyAgain,
            variant: AppButtonVariant.secondary,
            onPressed: () {
              unawaited(
                context.router.replace(
                  StudySessionRoute(deckId: deckId),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Return to Dashboard Action
          AppButton(
            text: l10n.sessionSummaryReturnDashboard,
            variant: AppButtonVariant.outline,
            onPressed: () {
              unawaited(
                context.router.replaceAll([
                  const MainRoute(children: [DashboardRoute()]),
                ]),
              );
            },
          ),
          const SizedBox(height: 12),

          // Browse All Decks Action
          AppButton(
            text: l10n.sessionSummaryBrowseDecks,
            variant: AppButtonVariant.ghost,
            onPressed: () {
              unawaited(
                context.router.replaceAll([
                  const MainRoute(children: [DecksRoute()]),
                ]),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
