import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:kortex/src/app/router/app_router.gr.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/features/planner/domain/entities/exam_event_entity.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

/// Modal sheets for linking flashcard decks with academic exam countdowns.
class ExamTimetableDeckAssociationSheet {
  static void showNoDecksModal(BuildContext context, ExamEventEntity exam) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 520,
        builder: (sheetCtx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(top: Radius.circular(24)),
            border: isDesktop
                ? Border.all(
                    color: colors.surfaceBorder.withValues(
                      alpha: isDark ? 0.3 : 0.15,
                    ),
                  )
                : null,
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: colors.black.withAlpha(isDark ? 100 : 35),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isDesktop) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'No Flashcard Decks Yet',
                style: typography.headline.bold.copyWith(color: colors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'To calibrate your study pace with real memory mastery, create flashcards for "${exam.examName}" or practice mock questions directly.',
                style: typography.body.regular.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  unawaited(
                    context.navigateTo(
                      MainRoute(children: [DecksRoute()]),
                    ),
                  );
                },
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: Text(context.l10n.plannerCreateStudyDeck),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  unawaited(
                    context.router.push(
                      MockExamLobbyRoute(
                        examId: exam.id,
                        examName: exam.examName,
                        subjectTrack: exam.subjectTrack,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.school_outlined),
                label: Text(context.l10n.plannerStartDiagnosticMock),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void showDeckPickerModal({
    required BuildContext context,
    required ExamEventEntity exam,
    required List<DeckEntity> decks,
    required void Function(DeckEntity deck) onSelectDeck,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    unawaited(
      AppAdaptiveSheet.showModal<void>(
        context: context,
        maxWidth: 600,
        builder: (sheetCtx) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.7,
              maxWidth: 600,
            ),
            decoration: BoxDecoration(
              color: isDark ? colors.surfaceSecondary : colors.surfacePrimary,
              borderRadius: isDesktop
                  ? BorderRadius.circular(AppRadius.dialog)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: colors.surfaceBorder.withValues(
                  alpha: isDark ? 0.3 : 0.15,
                ),
              ),
              boxShadow: isDesktop
                  ? [
                      BoxShadow(
                        color: colors.black.withAlpha(isDark ? 100 : 35),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDesktop) ...[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Linked Deck',
                            style: typography.headline.bold.copyWith(
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Choose flashcards that cover "${exam.examName}"',
                            style: typography.caption.regular.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: decks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final deck = decks[index];
                      final isAlreadyLinked =
                          exam.scopedDeckIds.contains(deck.id);
                      final masteryPct = (deck.masteryRate * 100).toInt();

                      return InkWell(
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          onSelectDeck(deck);
                        },
                        borderRadius: AppRadius.radiusCard,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isAlreadyLinked
                                ? colors.primary.withValues(alpha: 0.12)
                                : colors.surfacePrimary,
                            borderRadius: AppRadius.radiusCard,
                            border: Border.all(
                              color: isAlreadyLinked
                                  ? colors.primary
                                  : colors.surfaceBorder.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.radiusMicro,
                                ),
                                child: Icon(
                                  Icons.style_outlined,
                                  color: colors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deck.title,
                                      style: typography.body.semiBold.copyWith(
                                        color: colors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${deck.totalCards} cards • $masteryPct% mastery'
                                      '${deck.subject.isNotEmpty ? " • ${deck.subject}" : ""}',
                                      style: typography.caption.regular.copyWith(
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isAlreadyLinked)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.primary,
                                    borderRadius: AppRadius.radiusMicro,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check,
                                        size: 12,
                                        color: colors.white,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Linked',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.white,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: colors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetCtx).pop();
                      unawaited(
                        context.navigateTo(
                          MainRoute(children: [DecksRoute()]),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.l10n.plannerCreateNewDeck),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.radiusCard,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
