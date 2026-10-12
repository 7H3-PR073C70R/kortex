import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/navigation/app_tab_navigation.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/utils/app_logger.dart';
import 'package:kortex/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:kortex/src/features/quiz/presentation/widgets/quiz_duel_matchmaking_sheet.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// 4-column quick actions glass grid — mirrors the Stitch QuickActionsRow.
/// Upload Notes | Q-Bank | 1v1 Duel | New Deck
class DashboardQuickActionsGrid extends StatelessWidget {
  const DashboardQuickActionsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final l10n = context.l10n;

    String? getTrackCode() {
      try {
        final track = context.read<AuthBloc>().state.userProfile?.targetTrack;
        if (track != null && track.isNotEmpty) return track;
      } on Object catch (e, st) {
        AppLogger.recordNonFatal(e, st);
      }
      return null;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: neural.glassPanel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: neural.hairline),
          ),
          child: SizedBox(
            height: 124,
            width: double.infinity,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Upload Notes
                Expanded(
                  child: DashboardQuickActionCell(
                    icon: Icons.upload_file_rounded,
                    label: l10n.dashboardUploadNotes,
                    accent: neural.emerald400,
                    onTap: () {
                      AppFeedback.light();
                      _showUploadSheet(context);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Q-Bank
                Expanded(
                  child: DashboardQuickActionCell(
                    icon: Icons.quiz_rounded,
                    label: l10n.dashboardQBankAction,
                    accent: neural.amber400,
                    onTap: () {
                      AppFeedback.light();
                      final trackCode = getTrackCode();
                      unawaited(
                        context.router.push(
                          PastQuestionsBoardRoute(initialExamCode: trackCode),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 1v1 Duel
                Expanded(
                  child: DashboardQuickActionCell(
                    icon: Icons.flash_on_rounded,
                    label: '1v1 Duel',
                    accent: neural.cyan400,
                    onTap: () {
                      AppFeedback.light();
                      unawaited(QuizDuelMatchmakingSheet.show(context));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // New Deck
                Expanded(
                  child: DashboardQuickActionCell(
                    icon: Icons.create_new_folder_outlined,
                    label: l10n.dashboardNewDeck,
                    accent: neural.violet,
                    onTap: () {
                      AppFeedback.light();
                      AppTabNavigation.navigateTo(context, AppMainTab.decks);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUploadSheet(BuildContext context) {
    unawaited(
      context.router.push(DocumentIngestionRoute()),
    );
  }
}

class DashboardQuickActionCell extends StatelessWidget {
  const DashboardQuickActionCell({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final neural = context.neural;
    final typography = context.typography;

    return ShrinkableButton(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: neural.obsidian850.withAlpha(204),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: neural.hairlineSoft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withAlpha(26),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: typography.caption.medium.copyWith(
                color: neural.slate200,
                fontSize: 13.5,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
